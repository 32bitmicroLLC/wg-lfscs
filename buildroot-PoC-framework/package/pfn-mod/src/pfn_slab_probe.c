// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/debugfs.h>
#include <linux/uaccess.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <linux/io.h>

#define PROBE_NAME "pfn_slab_probe"
#define SCAN_ALIGN sizeof(void *)

static struct dentry *probe_dir;
static struct dentry *pfn_file;

static unsigned long last_input_pfn;
static unsigned long last_checked_pfn;
static unsigned long last_hits;
static unsigned long last_nearest_offset;
static bool last_valid_pfn;

static void probe_previous_pfn(unsigned long input_pfn)
{
	unsigned long checked_pfn;
	struct page *page;
	void *base;
	void *end;
	void *p;
	bool hit = false;

	last_input_pfn = input_pfn;
	last_hits = 0;
	last_nearest_offset = 0;
	last_valid_pfn = false;

	if (input_pfn == 0) {
		pr_info(PROBE_NAME ": invalid input PFN 0\n");
		return;
	}

	checked_pfn = input_pfn - 1;
	last_checked_pfn = checked_pfn;

	if (!pfn_valid(checked_pfn)) {
		pr_info(PROBE_NAME ": PFN %lu is not valid\n", checked_pfn);
		return;
	}

	last_valid_pfn = true;
	page = pfn_to_page(checked_pfn);

	pr_info(PROBE_NAME ": input_pfn=%lu checked_pfn=%lu flags=0x%lx\n",
		input_pfn, checked_pfn, page->flags);

	if (!PageSlab(page)) {
		pr_info(PROBE_NAME ": checked PFN %lu is not a slab page\n",
			checked_pfn);
		return;
	}

	base = __va(PFN_PHYS(checked_pfn));
	end = base + PAGE_SIZE;

	pr_info(PROBE_NAME ": checked PFN %lu is slab-backed, scanning [%px - %px)\n",
		checked_pfn, base, end);

	/*
	 * We scan backwards because the relevant safety case is:
	 *
	 *   [kernel slab page][user page]
	 *
	 * The object closest to the end of the kernel page is the object whose
	 * overflow is most naturally adjacent to the next PFN.
	 */
	for (p = end - SCAN_ALIGN; p >= base; p -= SCAN_ALIGN) {
		if (kmem_dump_obj(p)) {
			last_hits++;
			last_nearest_offset = p - base;

			pr_info(PROBE_NAME ": nearest candidate object at %px, offset 0x%lx into PFN %lu\n",
				p, last_nearest_offset, checked_pfn);

			hit = true;
			break;
		}

		if (p == base)
			break;
	}

	if (!hit)
		pr_info(PROBE_NAME ": slab page found, but no object candidate accepted by kmem_dump_obj()\n");
}

static ssize_t pfn_write(struct file *file,
			 const char __user *ubuf,
			 size_t len,
			 loff_t *ppos)
{
	char buf[64];
	unsigned long pfn;
	int ret;

	if (len >= sizeof(buf))
		return -EINVAL;

	if (copy_from_user(buf, ubuf, len))
		return -EFAULT;

	buf[len] = '\0';

	ret = kstrtoul(buf, 0, &pfn);
	if (ret)
		return ret;

	probe_previous_pfn(pfn);

	return len;
}

static ssize_t pfn_read(struct file *file,
			char __user *ubuf,
			size_t len,
			loff_t *ppos)
{
	char buf[512];
	int n;

	n = scnprintf(buf, sizeof(buf),
		      "last_input_pfn:      %lu\n"
		      "last_checked_pfn:    %lu\n"
		      "checked_pfn_valid:   %s\n"
		      "kmem_dump_obj_hits:  %lu\n"
		      "nearest_offset:      0x%lx\n"
		      "note:                details are emitted to dmesg by kmem_dump_obj()\n",
		      last_input_pfn,
		      last_checked_pfn,
		      last_valid_pfn ? "yes" : "no",
		      last_hits,
		      last_nearest_offset);

	return simple_read_from_buffer(ubuf, len, ppos, buf, n);
}

static const struct file_operations pfn_fops = {
	.owner = THIS_MODULE,
	.write = pfn_write,
	.read = pfn_read,
	.llseek = default_llseek,
};

static int __init pfn_slab_probe_init(void)
{
	probe_dir = debugfs_create_dir(PROBE_NAME, NULL);
	if (IS_ERR_OR_NULL(probe_dir))
		return -ENOMEM;

	pfn_file = debugfs_create_file("pfn", 0600, probe_dir, NULL, &pfn_fops);
	if (IS_ERR_OR_NULL(pfn_file)) {
		debugfs_remove_recursive(probe_dir);
		return -ENOMEM;
	}

	pr_info(PROBE_NAME ": loaded\n");
	return 0;
}

static void __exit pfn_slab_probe_exit(void)
{
	debugfs_remove_recursive(probe_dir);
	pr_info(PROBE_NAME ": unloaded\n");
}

module_init(pfn_slab_probe_init);
module_exit(pfn_slab_probe_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("blabla");
MODULE_DESCRIPTION("Inspect PFN-1 and emit nearest SLUB object via kmem_dump_obj()");
