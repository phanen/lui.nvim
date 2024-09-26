local Ui = {}

local api = vim.api

local options = {
  win_config = {
    relative = 'cursor',
    anchor = 'SW',
    border = 'single',
    style = 'minimal',
    noautocmd = true,
    title_pos = 'left',
    row = 0,
    col = 0,
    height = 1,
  },
}

---@class (exact) ui.InputOptions
---@field prompt? string
---@field default? string
---@field win? table
---@field completion? string
---@field highlight? string|fun(text: string): any[][]

---@param opts ui.InputOptions|string|nil
---@param on_confirm fun(text?: string)
Ui.input = function(opts, on_confirm)
  assert(vim.is_callable(on_confirm))
  if type(opts) == 'string' then opts = { prompt = tostring(opts) } end
  opts = vim.tbl_deep_extend('force', options, opts or {})

  local prompt = opts.prompt and (opts.prompt:gsub('\n', ' ')) or 'Input: '
  local default = opts.default and (opts.default:gsub('\n', ' ' or '')) or ''

  -- create win
  local win_config = opts.win_config
  win_config.width = math.max(api.nvim_strwidth(default) + 4, api.nvim_strwidth(prompt) + 2)
  win_config.title = prompt
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, true, { default })
  local win = api.nvim_open_win(buf, true, win_config)
  vim.wo[win].wrap = false
  vim.wo[win].list = true
  vim.wo[win].listchars = 'precedes:…,extends:…'
  vim.wo[win].sidescrolloff = 0

  -- auto resize win
  local curr_width, prev_width = api.nvim_strwidth(default), nil
  local id = api.nvim_create_autocmd({ 'TextChangedI' }, {
    buffer = buf,
    callback = function()
      curr_width, prev_width = api.nvim_strwidth(api.nvim_get_current_line()), curr_width
      local _opts = api.nvim_win_get_config(win)
      _opts.width = _opts.width + curr_width - prev_width
      api.nvim_win_set_config(win, _opts)
    end,
  })

  local do_exit = function()
    api.nvim_del_autocmd(id)
    api.nvim_win_close(win, true)
    vim.cmd('stopinsert')
  end

  local do_confirm = function()
    local line = api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    if line ~= default then on_confirm(line) end
    do_exit()
  end

  vim.keymap.set('i', '<cr>', do_confirm, { buffer = buf })
  vim.keymap.set('i', '<esc>', do_confirm, { buffer = buf })

  vim.cmd('startinsert!')
end

return setmetatable(Ui, {
  __index = function(t, k)
    rawset(t, k, require('vim.ui')[k])
    return rawget(t, k)
  end,
})
