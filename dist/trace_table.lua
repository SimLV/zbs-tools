--[[
  -- Copyright 2019 Sim
  -- MIT License
  
  From ZBS docs:
  To install a plugin, copy its .lua file to ZBS/packages/ or HOME/.zbstudio/packages/ folder (where ZBS is the path to ZeroBrane Studio location and HOME is the path specified by the HOME environment variable). The first location allows you to have per-instance plugins, while the second allows to have per-user plugins. The second option may also be preferrable for Mac OSX users as the ZBS/packages/ folder may be overwritten during an application upgrade.
--]]
local ide = ide

local ID_CLEAR_ALL          = ID('trace_table:clear_all')
local ID_DELETE_ROW         = ID('trace_table:delete_row')
local ID_CLEAR_PARTIAL      = ID('trace_table:clear_partial')

local fnClearPartial

local function displayError(...) return ide:GetOutput():Error(...) end

local data={portnumber= 1026,
  sock = false,
  key2Col = {},
  cols = 0,
}

function data.terminate() 
  if data.sock then
    data.sock:close()
    data.sock = false
  end
end

local function makeSocket()
  if data.sock then return end
  local cln = socket.udp()
  local ok, err = cln:setsockname("*",data.portnumber)
  if not ok then
    displayError(TR("Can't start server at %s:%d: %s.")
      :format(data.portnumber, err or TR("unknown error")))
    return
  end
  cln:settimeout(0)
  
  --local server, err = socket.bind("*", data.portnumber)
  
  ide:Print(TR("Trace server started at *:%d."):format(data.portnumber))

  data.sock = cln
  return cln
end

local function startServer()
  local server = makeSocket()
end

local function createWindow()
  local width, height = 360, 200
  local sash = ide:GetUIManager():GetArtProvider():GetMetric(wxaui.wxAUI_DOCKART_SASH_SIZE)
  local border = sash + 2
  
  local back = wx.wxPanel(ide:GetMainFrame(), wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize)
  
  local oneItem = ide:CreateStyledTextCtrl(back, wx.wxID_ANY,
    wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxBORDER_NONE)
  
  local ctrl = wx.wxGrid(back, wx.wxID_ANY,
    wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxNO_BORDER)
  
  
  ctrl:CreateGrid(1, 2)--wx.wxGridSelectRows)
  --ctrl:SetRowLabelSize(0)
  --ctrl:SetColLabelValue(0, TR('Time'))
  ctrl:EnableEditing(false)
  ctrl:SetDefaultCellOverflow(false)
  --ctrl:SetImageList(outline.imglist)
  ctrl:SetFont(ide.font.tree)

  local topSizer = wx.wxBoxSizer(wx.wxVERTICAL)
  topSizer:Add(ctrl, 3, wx.wxLEFT + wx.wxRIGHT + wx.wxTOP + wx.wxALIGN_LEFT + wx.wxEXPAND, 1)
  topSizer:AddSpacer(4)
  topSizer:Add(oneItem, 1, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM + wx.wxEXPAND, 1)
  back:SetSizer(topSizer)
  back:GetSizer():Fit(back)

  data.ctrl = ctrl
  
  --oneItem:SetReadOnly(true)
  
  local col = -1
  ctrl:Connect(wx.wxEVT_GRID_SELECT_CELL, function(event)
      local col = event:GetCol()
      local row = event:GetRow()
      if col>=0 and row>= 0 then
        local val = ctrl:GetCellValue(row, col)
        ctrl:SetToolTip(val)
        oneItem:SetText(val)
      else
        ctrl:SetToolTip('')
        oneItem:SetText('')
      end
    end)
  
  ctrl:Connect(wx.wxEVT_GRID_CELL_RIGHT_CLICK,
    function (event)
      col = event:GetCol()
      local menu = ide:MakeMenu {
        { ID_CLEAR_ALL, TR("Clear all") },
        { ID_CLEAR_PARTIAL, TR("Clear rows") },
        { ID_DELETE_ROW, TR("Delete column") },
      }
      do
        collectgarbage("stop")

      -- stopping UI updates is generally not needed as well,
      -- but it's causing a crash on OSX (wxwidgets 2.9.5 and 3.1.0)
      -- when symbol indexing is done while popup menu is open, so it's disabled
        local interval = wx.wxUpdateUIEvent.GetUpdateInterval()
        wx.wxUpdateUIEvent.SetUpdateInterval(-1) -- don't update

        ctrl:PopupMenu(menu)
        wx.wxUpdateUIEvent.SetUpdateInterval(interval)
        collectgarbage("restart")
      end
    end
  )
  ctrl:Connect(ID_CLEAR_ALL, wx.wxEVT_COMMAND_MENU_SELECTED,
    function()
      data.cols = 0
      if ctrl:GetNumberCols() < 2 then
        ctrl:AppendCols(2 - ctrl:GetNumberCols())
      else
        ctrl:DeleteCols(0, ctrl:GetNumberCols()-2)
      end
      ctrl:SetColLabelValue(0, 'A')
      ctrl:SetColLabelValue(1, 'B')
      ctrl:DeleteRows(0, ctrl:GetNumberRows())
      ctrl:AppendRows(1)
      ctrl:SetRowLabelValue(0, 'time')
      oneItem:SetText('')
      data.key2Col = {}
    end)
  fnClearPartial = function()
      data.cols = 0
      if ctrl:GetNumberCols() < 2 then
        ctrl:AppendCols(2 - ctrl:GetNumberCols())
      end
      ctrl:DeleteRows(0, ctrl:GetNumberRows())
      ctrl:AppendRows(1)
      ctrl:SetRowLabelValue(0, 'time')
      oneItem:SetText('')
      data.key2Col = {}
    end
  ctrl:Connect(ID_CLEAR_PARTIAL, wx.wxEVT_COMMAND_MENU_SELECTED, fnClearPartial)
  ctrl:Connect(ID_DELETE_ROW, wx.wxEVT_COMMAND_MENU_SELECTED,
    function()
      if col >= 0 then
        local str = ctrl:GetColLabelValue(col)
        data.key2Col[str] = nil
        for k, v in pairs(data.key2Col) do
          if v > col then
            data.key2Col[k] = v - 1
          end
        end
        data.cols = data.cols - 1
        ctrl:DeleteCols(col)
        oneItem:SetText('')
        col = -1
      end
    end)
  
  
  local function reconfigure(pane)
    pane:TopDockable(false):BottomDockable(false)
        :MinSize(150,-1):BestSize(300,-1):FloatingSize(200,300)
  end

  local layout = ide:GetSetting("/view", "uimgrlayout")
  if not layout or not layout:find("tracepanel") then
    ide:AddPanelDocked(ide:GetProjectNotebook(), back, "tracepanel", TR("Trace"), reconfigure, false)
  else
    ide:AddPanel(back, "tracepanel", TR("Trace"), reconfigure)
  end
end

local function add_cell(key, val, mtype, rowN)
  local tb = data.ctrl
  if key then
    if rowN == nil then
      rowN = tb:GetNumberRows() - 1
      tb:AppendRows(1)
      tb:SetRowLabelValue(rowN+1, 'time')

      tb:SetRowLabelValue(rowN, string.format('%07.3f',ide.GetTime() - data.startTime))
    end
    
    local colN = data.key2Col[key]
    if not colN then
      colN = data.cols
      data.cols = colN + 1
      if tb:GetNumberCols() < data.cols then
        tb:AppendCols(1)
      end
      tb:SetColLabelValue(colN, key)
      data.key2Col[key] = colN
    end
    tb:SetCellValue(rowN, colN, val)
    if val:find('\n',1,true) then
      local r = tb:GetDefaultRenderer()
      local dc = wx.wxClientDC(tb) -- возможно стоит их где-то сложить
      local attr = tb:GetOrCreateCellAttr(rowN, colN)
      local sz = r:GetBestSize(tb, attr, dc, rowN, colN)
      tb:SetRowSize(rowN, sz:GetHeight())
    end
    tb:MakeCellVisible(rowN, colN)
    return rowN
  end
end

return {
 name = "Trace table",
  description = "Show a table to view messages(usable for event debugging).",
  author = "Sim",
  version = 0.2,
  dependencies = 0.78,
    onRegister = function(self)
      if ide.config.tracedisable then return end
      createWindow()
      makeSocket()
      data.startTime = ide.GetTime()
    end,
    onIdle = function(self)
      if not data.sock then return end
      local msg, ip, port = data.sock:receivefrom()
      if not msg then
        if ip ~= 'timeout' then
          displayError(TR('re ')..ip)
        end
        return
      else

        local key, val, mtype = msg:match([[([^:]*):(.*)|(.*)]])
        local rowN
        for key_part in key:gmatch([[([^,]+),?]]) do
          rowN = add_cell(key_part, val, mtype, rowN)
        end
      end
    end,
    onInterpreterLoad = function(self)
      if fnClearPartial then fnClearPartial() end
    end,
    onAppClose = function(self)
      data.terminate()
    end,
  }