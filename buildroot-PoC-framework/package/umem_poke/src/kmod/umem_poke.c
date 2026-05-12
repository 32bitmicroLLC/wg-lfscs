// SPDX-License-Identifier: GPL-2.0
#include <linux/mm.h>
#include <linux/mm_types.h>
#include <linux/pid.h>
#include <linux/sched/mm.h>
#include <linux/highmem.h>
#include <linux/err.h>
#include <linux/version.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/pid.h>

#define UMEM_POKE_MAX_INPUT 128


struct user_linear_mapping {
	void *kaddr;
	struct page *page;
};

struct action {
	void *addr;
	unsigned long value;
	pid_t pid;
};

static inline bool page_is_ksm(struct page *page)
{
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 13, 0)
    return folio_test_ksm(page_folio(page));
#else
    return PageKsm(page);
#endif
}

static inline bool page_is_mapped_shared(struct page *page)
{
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 11, 0)
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 15, 0)
	return folio_maybe_mapped_shared(page_folio(page));
#else
	return folio_likely_mapped_shared(page_folio(page));
#endif
#else
	return page_mapcount(page) > 1;
#endif
}

static void put_user_linear_mapping(struct user_linear_mapping *m)
{
	if (m && m->page) {
		put_page(m->page);
		m->page = NULL;
		m->kaddr = NULL;
	}
}

static int get_user_linear_mapping(pid_t pid, unsigned long uaddr,
				   struct user_linear_mapping *out)
{
	struct task_struct *task;
	struct mm_struct *mm;
	struct page *page = NULL;
	unsigned int gup_flags = FOLL_NOFAULT;
	unsigned long offset = offset_in_page(uaddr);
	long nr;
	void *kaddr;
	int ret = 0;

	if (!out)
		return -EINVAL;

	out->kaddr = NULL;
	out->page = NULL;

	rcu_read_lock();
	task = pid_task(find_vpid(pid), PIDTYPE_PID);
	if (task)
		get_task_struct(task);
	rcu_read_unlock();

	if (!task)
		return -ESRCH;

	mm = get_task_mm(task);
	put_task_struct(task);

	if (!mm)
		return -EINVAL;

	mmap_read_lock(mm);

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 5, 0)
	nr = get_user_pages_remote(mm, uaddr, 1, gup_flags, &page, NULL);
#else
	nr = get_user_pages_remote(NULL, mm, uaddr, 1, gup_flags, &page, NULL, NULL);
#endif

	mmap_read_unlock(mm);
	mmput(mm);

	if (nr != 1)
		return nr < 0 ? nr : -EFAULT;

	if (is_zero_pfn(page_to_pfn(page))) {
		ret = -EFAULT;
		goto out_put;
	}

	if (PageAnon(page) && !page_is_ksm(page) && page_is_mapped_shared(page)) {
		ret = -EAGAIN;
		goto out_put;
	}

	kaddr = page_address(page);
	if (!kaddr) {
		ret = -EFAULT;
		goto out_put;
	}

	kaddr = (char *)kaddr + offset;

	if (!virt_addr_valid(kaddr)) {
		ret = -EFAULT;
		goto out_put;
	}

	out->page = page;
	out->kaddr = kaddr;
	return 0;

out_put:
	put_page(page);
	return ret;
}

static int parse_action(const char *buf, struct action *act)
{
	unsigned long addr;
	unsigned long value;
	pid_t pid;
	int n;

	n = sscanf(buf, "%d:%lx:%lx", &pid, &addr, &value);
	if (n != 3)
		return -EINVAL;

	if (pid <= 0)
		return -EINVAL;

	pr_info("umem_poke: req: poke memory for pid=%d mem[%lx]=%lx\n",
		pid, addr, value);

	act->pid = pid;
	act->addr = (void *)addr;
	act->value = value;

	return 0;
}

static ssize_t umem_poke_write(struct file *file,
			     const char __user *ubuf,
			     size_t len,
			     loff_t *ppos)
{
	struct user_linear_mapping dst;
	char buf[UMEM_POKE_MAX_INPUT];
	unsigned long *dst_target;
	struct action act;
	int ret;


	if (len == 0 || len >= sizeof(buf))
		return -EINVAL;

	if (copy_from_user(buf, ubuf, len))
		return -EFAULT;

	buf[len] = '\0';

	ret = parse_action(buf, &act);
	if (ret)
		return ret;

	get_user_linear_mapping(act.pid, (unsigned long) act.addr, &dst);
	dst_target = (unsigned long *) dst.kaddr;
	pr_info("umem_poke: act: poke memory for pid=%d mem[%lx]=%lx\n",
		act.pid, (unsigned long) act.addr, (unsigned long) act.value);

	if (!dst_target)
		return -EFAULT;

	*dst_target = act.value;
	put_user_linear_mapping(&dst);

	return len;
}

static const struct proc_ops umem_poke_ops = {
	.proc_write = umem_poke_write,
};

static struct proc_dir_entry *umem_poke_entry;

static int __init umem_poke_init(void)
{
	umem_poke_entry = proc_create("umem_poke", 0200, NULL, &umem_poke_ops);
	if (!umem_poke_entry)
		return -ENOMEM;

	return 0;
}

static void __exit umem_poke_exit(void)
{
	proc_remove(umem_poke_entry);
}

module_init(umem_poke_init);
module_exit(umem_poke_exit);
MODULE_LICENSE("GPL");
