return {
	-- Short model per PHYSICAL disk. Write it once here — the plugin resolves
	-- a partition (e.g. /dev/nvme1n1p5) back to its physical disk (nvme1n1)
	-- and picks up the model automatically.
	models = {
		nvme1n1 = "Samsung 990", -- Samsung 990 EVO Plus 4TB (CachyOS system disk)
		nvme0n1 = "Crucial P3",  -- CT4000P3PSSD8 4TB
		sda = "Samsung 870",     -- 870 QVO 2TB
		sdb = "Patriot P210",    -- P210 512GB
		sdc = "Intel 660p",      -- SSDPEKNW020T8 2TB
		sdd = "WD Blue",         -- WDS100T2B0C 1TB
	},

	-- Role per partition source / pool / host. Shown after the model,
	-- colon-separated, e.g. "Samsung 990:Windows".
	roles = {
		["/dev/nvme1n1p5"] = "CachyOS",     -- btrfs root: /, /home, /srv, /var/* ...
		["/dev/nvme1n1p6"] = "CachyData",   -- /mnt/cachydata
		["/dev/nvme1n1p2"] = "Windows",     -- /mnt/Windows
		["/dev/nvme1n1p1"] = "EFI",         -- /boot/efi

		["/dev/nvme0n1p2"] = "Crucial4TB",  -- /mnt/Crucial4TB

		["/dev/sda1"] = "Downloads2TB",     -- /mnt/Downloads2TB
		["/dev/sdb2"] = "Patriot512GB",     -- /mnt/Patriot512GB
		["/dev/sdc1"] = "Intel2TB",         -- /mnt/Intel2TB
		["/dev/sdd1"] = "WD1TB",            -- /mnt/WD1TB

		-- mergerfs pools (no /dev/ prefix → no model, just the role)
		["Movies-Pool"] = "Movies",
		["Downloads-Pool"] = "Downloads",

		-- sshfs: source looks like `regina@macmini1:/...` — key by the host prefix
		["regina@macmini1"] = "Mac mini",
	},

	-- Icons per physical disk and per role. Prepended by canonical() in the
	-- disk-bar plugin, e.g. "🚀 Samsung 990:🐧 CachyOS".
	icons = {
		disks = {
			nvme1n1 = "🚀", -- Samsung 990 EVO Plus 4TB — самый быстрый NVMe
			nvme0n1 = "🗄️", -- Crucial P3 4TB — второй NVMe
			sda = "💽",       -- Samsung 870 QVO 2TB
			sdb = "💽",       -- Patriot P210 512GB
			sdc = "💽",       -- Intel 660p 2TB
			sdd = "💽",       -- WD Blue 1TB
		},
		roles = {
			CachyOS      = "🐧",
			CachyData    = "🗄️",
			Windows      = "🪟",
			EFI          = "⚙️",
			Crucial4TB   = "💿",
			Downloads2TB = "📥",
		Downloads    = "📥", -- mergerfs-пул ~/Downloads-Pool
			Patriot512GB = "💿",
			Intel2TB     = "💿",
			WD1TB        = "💿",
			Movies       = "🎬",
			["Mac mini"] = "🖥️",
		},
	},
}
