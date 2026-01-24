-- Track if DAP is already set up for this project
local dap = require("dap")
local dap_setup_done = {}

local unity_event_bus = require("config.unihug.event-bus")
unity_event_bus.set_neotree_preload(function(args)
  args.hide_root_node = true
  args.close_if_last_window = true
  args.filesystem.filtered_items = {
    never_show_by_pattern = { "*.meta" },
    hide_dotfiles = true,
    hide_gitignored = true,
    hide_hidden = true, -- only works on Windows for hidden files/directories
  }

  -- args.filesystem.filtered_items = { never_show_by_pattern = { ".*", "!*.cs" } } -- Hide everything except `.cs` fileshow dotfiles for this buffer type
  -- args.filesystem.bind_to_cwd = true
  args.filesystem.follow_current_file = { enabled = true }
  args.filesystem.use_libuv_file_watcher = true
  args.root_dir = vim.fn.getcwd()

  -- Create a custom source
  local custom_source = {
    name = "my_custom_source", -- unique name for your source

    get_items = function(state)
      -- Return your custom items
      return {
        {
          id = "1",
          name = "Custom Item 1",
          type = "file", -- or "directory"
          path = "/path/to/item", -- full path
        },
        {
          id = "2",
          name = "Custom Item 2",
          type = "directory",
          path = "/another/path",
        },
      }
    end,

    components = { -- Define how items are displayed
      icon = function(config, node, state)
        return "🔥" -- or any custom icon logic
      end,
      name = function(config, node, state)
        return node.name
      end,
    },
  }
  args.sources = { "example" }
  args.source_selector = {
    winbar = true,
    content_layout = "center",
    sources = {
      -- { source = "filesystem", display_name = " Files" },
      -- { source = "buffers", display_name = " Buffers" },
      -- { source = "git_status", display_name = " Git" },
      { source = "cs_files", display_name = " C# Files" },
    },
  }
  args.example = {
    -- The config for your source goes here. This is the same as any other source, plus whatever
    -- special config options you add.
    -- window = {...}
    renderers = {
      file = {
        -- Define components to be used when rendering files
        -- {
        -- 	"icon", -- Default icon component
        -- },
        {
          "name", -- Default name component
          highlight = "NeoTreeFileName",
          -- Optionally customize the display of the name
          render = function(config, node)
            return node.name .. " [Custom File]"
          end,
        },
      },
      directory = {
        -- Define components to be used when rendering directories
        {
          "icon", -- Default icon component
        },
        {
          "name", -- Default name component
          highlight = "NeoTreeDirectoryName",
          -- Optionally customize the display of the directory name
          render = function(config, node)
            return "📂 " .. node.name .. " [Custom Directory]"
          end,
        },
      },
    },
    --etc
  }
  print("successfully called preload", vim.inspect(args))
end)

local function setup_unity_dap()
  -- Skip if not a C# file
  if vim.bo.filetype ~= "cs" then
    return
  end

  local function find_unity_root()
    local current = vim.fn.getcwd()
    while current ~= "/" do
      local has_library = vim.fn.isdirectory(current .. "/Library") == 1
      local has_assets = vim.fn.isdirectory(current .. "/Assets") == 1

      if has_library and has_assets then
        return current
      end
      current = vim.fn.fnamemodify(current, ":h")
    end
    return nil
  end

  local unity_root = find_unity_root()
  if not unity_root then
    return
  end

  -- Check if DAP is already set up for this project root
  if dap_setup_done[unity_root] then
    return
  end

  local config_path = vim.fn.stdpath("config")

  -- dap.adapters.coreclr = {
  -- 	type = "executable",
  -- 	command = config_path .. "/netcoredbg/netcoredbg",
  -- 	args = { "--interpreter=vscode" },
  -- }
  --
  -- dap.configurations.cs = {
  -- 	{
  -- 		type = "coreclr",
  -- 		name = "launch - netcoredbg",
  -- 		request = "launch",
  -- 		program = function()
  -- 			return vim.fn.input("Path to dll", vim.fn.getcwd() .. "/bin/Debug/", "file")
  -- 		end,
  -- 	},
  -- }

  local vstuc_path = config_path .. "/tools/VisualStudioToolsForUnity.vstuc-1.0.5/extension/bin/"

  dap.adapters.vstuc = {
    type = "executable",
    command = "dotnet",
    -- command = "c:/Program Files/Unity/Hub/Editor/2022.3.53f1/Editor/Data/MonoBleedingEdge/bin/mono.exe",
    args = { vstuc_path .. "UnityDebugAdapter.dll" },
    name = "Attach to Unity",
  }

  dap.configurations.cs = {
    {
      type = "vstuc",
      request = "attach",
      name = "Attach to Unity",
      path = unity_root and (unity_root .. "/Library/EditorInstance.json") or "",
      --:NOTE in some uknown case when root is not found we return list of Unity processes so user can select them by hand
      processId = (not unity_root) and function()
        return require("dap.utils").pick_process({
          filter = function(proc)
            return proc.name:lower():find("unity") ~= nil
          end,
        })
      end or nil,
      projectPath = unity_root,
      endPoint = function()
        local system_obj = vim.system({ "dotnet", vstuc_path .. "UnityAttachProbe.dll" }, { text = true })
        local probe_result = system_obj:wait(2000).stdout
        if probe_result == nil or #probe_result == 0 then
          print("No endpoint found (is unity running?)")
          return ""
        end
        for json in vim.gsplit(probe_result, "\n") do
          if json ~= "" then
            local probe = vim.json.decode(json)
            for _, p in pairs(probe) do
              if p.isBackground == false then
                return p.address .. ":" .. p.debuggerPort
              end
            end
          end
        end
        return ""
      end,
    },
  }

  -- set neovim's working directory
  -- local root_dir = unity_root .. "/assets"
  -- if root_dir then
  --   vim.cmd("cd " .. root_dir)
  -- end

  -- Configure Neo-tree to show only .cs files
  -- local lazy = require("lazy")
  -- -- local plugin = lazy.plugins["neo-tree.nvim"]
  --
  -- local dap_status_ok, neotree = pcall(require, 'neo-tree.nvim"')
  --
  -- if dap_status_ok then
  --   print("Neo-tree is loaded")
  -- else
  --   print("Neo-tree is not loaded")
  -- end

  -- Or for a specific plugin:
  -- require("lazy.events").on("LazyLoad", function(plugin)
  --   if plugin.name == "neo-tree.nvim" then
  --     print("Neo-tree is loaded")
  --   end
  -- vim.api.nvim_create_autocmd("User", {
  --   pattern = "neo-tree:setup_after", -- Replace `snacks.nvim` with the plugin's name
  --   callback = function(args)
  --     -- Your custom function or logic here
  --     print("neotree.options:" .. args.data.opts.popup_border_style)
  --     require("neo-tree").set({
  --       filesystem = {
  --         filtered_items = {
  --           -- Example: only show files matching specific patterns
  --           hide_dotfiles = false,
  --           hide_by_pattern = { "*.meta" }, -- Hide log files
  --           -- never_show_by_pattern = { ".*", "!*.cs" }, -- Hide everything except `.cs` fileshow dotfiles for this buffer type
  --         },
  --       },
  --     })
  --   end,
  -- })

  -- Update only the filter settings (don't reset the entire setup)
  -- require("neo-tree").set({
  --   filesystem = {
  --     filtered_items = {
  --       -- Example: only show files matching specific patterns
  --       hide_dotfiles = false,
  --       hide_by_pattern = { "*.meta" }, -- Hide log files
  --       -- never_show_by_pattern = { ".*", "!*.cs" }, -- Hide everything except `.cs` fileshow dotfiles for this buffer type
  --     },
  --   },
  -- })

  -- Optionally refresh Neo-tree if needed
  -- vim.cmd("Neotree refresh")

  -- fs_config.filtered_items.custom = {
  -- 	{
  -- 		pattern = function(name, _)
  -- 			-- Hide everything that doesn't end with .cs
  -- 			return not string.match(name, "%.cs$")
  -- 		end,
  -- 		display_name = "Non-C# files",
  -- 	},
  -- }

  -- fs_config.filtered_items = {
  -- 	{
  -- 		never_show_by_pattern = { ".*", "!*.cs" }, -- Hide everything except `.cs` files
  -- 	},
  -- }

  -- require("neo-tree.sources.filesystem.commands").refresh(require("neo-tree.sources.manager").get_state(
  -- "filesystem"))
  -- require("neo-tree.sources.filesystem.commands").refresh({})

  -- Mark this project as set up
  dap_setup_done[unity_root] = true

  vim.notify("UNIHUG: opened project:" .. unity_root .. "\n VSToolsPath:" .. vstuc_path, vim.log.levels.INFO)
  -- require("notify")(
  --   "UNICHAD: opened project:" .. unity_root .. "\n VSToolsPath:" .. vstuc_path,
  --   "UNICHAD setup",
  --   { title = "Debugger is ready" }
  -- )
end

return setup_unity_dap
