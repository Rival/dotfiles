return {
  "kosayoda/nvim-lightbulb",
  event = "VeryLazy",
  config = function()
    require("nvim-lightbulb").setup({
      -- 4. Status text.
      -- When enabled, will allow using |NvimLightbulb.get_status_text|
      -- to retrieve the configured text.
      status_text = {
        enabled = true,
        -- Text to set if a lightbulb is available.
        text = "💡",
        lens_text = "🔎",
        -- Text to set if a lightbulb is unavailable.
        text_unavailable = "",
      },
      -- 5. Number column.
      number = {
        enabled = true,
        -- Highlight group to highlight the number column if there is a lightbulb.
        hl = "LightBulbNumber",
      },
    })
  end,
  opts = {
    config = {
      -- 4. Status text.
      -- When enabled, will allow using |NvimLightbulb.get_status_text|
      -- to retrieve the configured text.
      status_text = {
        enabled = true,
        -- Text to set if a lightbulb is available.
        text = "💡",
        lens_text = "🔎",
        -- Text to set if a lightbulb is unavailable.
        text_unavailable = "",
      },
      -- 5. Number column.
      number = {
        enabled = true,
        -- Highlight group to highlight the number column if there is a lightbulb.
        hl = "LightBulbNumber",
      },
    },
  },
}
