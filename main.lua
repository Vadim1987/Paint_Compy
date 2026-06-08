-- main.lua

-- screen

WIDTH, HEIGHT = gfx.getDimensions()

-- color palette

BLOCK_W = WIDTH / 10
BLOCK_H = BLOCK_W / 2
PAL_H = 2 * BLOCK_H
PAL_W = 8 * BLOCK_W
SEL_W = 2 * BLOCK_W
PAL_COLS = 8

-- tool pane

MARGIN = BLOCK_H / 10
M_2 = MARGIN * 2
M_4 = MARGIN * 4
BOX_W = 1.5 * BLOCK_W
BOX_H = HEIGHT - PAL_H
MARG_L = BOX_W - M_2
TOOL_H = BOX_H / 2
TOOL_MIDX = BOX_W / 2

N_T = 2
BRUSH = 1
ERASER = 2
ICON_H = (TOOL_H - M_4 - M_2) / N_T
ICON_W = (BOX_W - M_4 - M_4) / 1
ICON_D = math.min(ICON_W, ICON_H)
ICON_BASE = 100
ICON_ANGLE = math.pi / 4
ERASER_SCALE = 1.5
STEP_FRAC = 0.5

-- line weight

WEIGHT_H = BOX_H / 2
WB_Y = BOX_H - WEIGHT_H
WEIGHTS = { 1, 2, 4, 5, 6, 9, 11, 13 }

--- canvas

CAN_W = WIDTH - BOX_W
CAN_H = BOX_H - 1
canvas = gfx.newCanvas(CAN_W, CAN_H)

-- goose marker for selected weight, drawn around y = 0

GOOSE = { 0.303, 0.431, 0.431 }
GOOSE_SHAPE = {
  5 * MARGIN, -MARGIN,
  3 * MARGIN, -MARGIN,
  3 * MARGIN, MARGIN,
  5 * MARGIN, MARGIN,
  5 * MARGIN, M_2,
  7 * MARGIN, 0,
  5 * MARGIN, -M_2,
}

COLORKEYS = {
  ['1'] = 0,
  ['2'] = 1,
  ['3'] = 2,
  ['4'] = 3,
  ['5'] = 4,
  ['6'] = 5,
  ['7'] = 6,
  ['8'] = 7,
}

-- selected state

color = 0    
bg_color = 0 
weight = 3
tool = BRUSH 
brush_tip = nil

-- range tests

function inCanvasRange(x, y)
  return (y < BOX_H and BOX_W < x)
end

function inPaletteRange(x, y)
  return (BOX_H <= y
    and WIDTH - PAL_W <= x and x <= WIDTH)
end

function inToolRange(x, y)
  return (x <= BOX_W and y <= TOOL_H)
end

function inWeightRange(x, y)
  return (x <= BOX_W and y < BOX_H and WB_Y < y)
end

-- background and palette

function drawBackground()
  gfx.setColor(Color[Color.black])
  gfx.rectangle("fill", 0, 0, WIDTH, HEIGHT)
end

function drawPaletteOutline(y)
  gfx.setColor(Color[bg_color])
  gfx.rectangle("fill", 0, y - BLOCK_H,
    BLOCK_W * 2, BLOCK_H * 2)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("line", 0, y - BLOCK_H, SEL_W, PAL_H)
  gfx.rectangle("line", SEL_W, y - BLOCK_H, WIDTH, PAL_H)
end

function selectedOutlineColor()
  local lc = Color.white + Color.bright
  if color == lc then
    return Color.black
  end
  return lc
end

function drawSelectedColor(y)
  gfx.setColor(Color[color])
  gfx.rectangle("fill", BLOCK_W / 2, y - (BLOCK_H / 2),
    BLOCK_W, BLOCK_H)
  gfx.setColor(Color[selectedOutlineColor()])
  gfx.rectangle("line", BLOCK_W / 2, y - (BLOCK_H / 2),
    BLOCK_W, BLOCK_H)
end

function drawColorBox(c, x, y)
  gfx.setColor(Color[c])
  gfx.rectangle("fill", x, y, BLOCK_W, BLOCK_H)
  gfx.setColor(Color[c + PAL_COLS])
  gfx.rectangle("fill", x, y - BLOCK_H, BLOCK_W, BLOCK_H)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("line", x, y, BLOCK_W, BLOCK_H)
  gfx.rectangle("line", x, y - BLOCK_H, BLOCK_W, BLOCK_H)
end

function drawColorBoxes(y)
  for c = 0, PAL_COLS - 1 do
    drawColorBox(c, BLOCK_W * (c + 2), y)
  end
end

function drawColorPalette()
  local y = HEIGHT - BLOCK_H
  drawPaletteOutline(y)
  drawSelectedColor(y)
  drawColorBoxes(y)
end

-- tool icons

function beginIcon(cx, cy, s)
  gfx.push()
  gfx.translate(cx, cy)
  gfx.scale(s, s)
  gfx.rotate(ICON_ANGLE)
end

function getBrushTip()
  if not brush_tip then
    local curve = love.math.newBezierCurve(
      -12, 12, -15, 20, -5, 30,
      0, 35, 5, 30, 15, 20, 12, 12)
    brush_tip = curve:render()
  end
  return brush_tip
end

function drawBrushHandle()
  gfx.setColor(0.6, 0.4, 0.2)
  gfx.rectangle("fill", -8, -80, 16, 60)
  gfx.setColor(0.8, 0.6, 0.4)
  gfx.rectangle("fill", -6, -75, 3, 50)
end

function drawBrushFerrule()
  gfx.setColor(0.7, 0.7, 0.8)
  gfx.rectangle("fill", -10, -25, 20, 12)
  gfx.setColor(0.9, 0.9, 1.0)
  gfx.rectangle("fill", -8, -24, 3, 10)
end

function drawBrushBristles()
  gfx.setColor(0.2, 0.2, 0.2)
  gfx.rectangle("fill", -12, -13, 24, 25)
  gfx.polygon("fill", getBrushTip())
end

function drawBrush(cx, cy)
  beginIcon(cx, cy, ICON_D / ICON_BASE * 0.8)
  drawBrushHandle()
  drawBrushFerrule()
  drawBrushBristles()
  gfx.pop()
end

function drawEraserBody()
  gfx.setColor(Color[Color.white])
  gfx.rectangle("fill", -12, -40, 24, 60)
  gfx.setColor(Color[Color.blue])
  gfx.rectangle("fill", -12, -40, 6, 60)
  gfx.rectangle("fill", 6, -40, 6, 60)
  gfx.setColor(Color[Color.white + Color.bright])
  gfx.rectangle("fill", -12, 15, 24, 8)
end

function drawEraserCrumbs()
  gfx.setColor(Color[Color.white])
  gfx.circle("fill", 18, 25, 2)
  gfx.circle("fill", 22, 30, 1.5)
  gfx.circle("fill", 15, 32, 1)
end

function drawEraser(cx, cy)
  beginIcon(cx, cy, ICON_D / ICON_BASE)
  drawEraserBody()
  drawEraserCrumbs()
  gfx.pop()
end

TOOLS = {
  drawBrush,
  drawEraser,
}

function toolIconColor(i)
  if i == tool then
    return Color.black
  end
  return Color.white + Color.bright
end

function drawToolIcon(i)
  local tb = ICON_D
  local x = TOOL_MIDX - (tb / 2)
  local y = (i - 1) * (M_2 + tb)
  gfx.setColor(Color[toolIconColor(i)])
  gfx.rectangle("fill", x, y + M_2, tb, tb)
  gfx.setColor(Color[Color.black])
  gfx.rectangle("line", x, y + M_2, tb, tb)
  TOOLS[i](TOOL_MIDX - M_2, y + (tb / 2) + M_4)
end

function drawTools()
  for i = 1, N_T do
    drawToolIcon(i)
  end
end

-- line weight selector

function drawGooseMarker(mid)
  gfx.push()
  gfx.translate(0, mid)
  gfx.setColor(GOOSE)
  gfx.polygon("fill", GOOSE_SHAPE)
  gfx.setColor(Color[Color.black])
  gfx.setLineWidth(2)
  gfx.polygon("line", GOOSE_SHAPE)
  gfx.setLineWidth(1)
  gfx.pop()
end

function drawWeightBar(mid, lw)
  gfx.setColor(Color[Color.black])
  local aw = WEIGHTS[lw]
  gfx.rectangle("fill", BOX_W / 3, mid - (aw / 2),
    BOX_W / 2, aw)
end

function drawWeightRow(i, h)
  local y = WB_Y + MARGIN + (i * h)
  local lw = i + 1
  local mid = y + (h / 2)
  gfx.setColor(Color[Color.white + Color.bright])
  gfx.rectangle("fill", MARGIN, y, MARG_L, h)
  if lw == weight then
    drawGooseMarker(mid)
  end
  drawWeightBar(mid, lw)
end

function drawWeightSelector()
  gfx.setColor(Color[Color.white + Color.bright])
  gfx.rectangle("line", 0, BOX_H - WEIGHT_H,
    BOX_W - 1, WEIGHT_H)
  local h = (WEIGHT_H - M_2) / #WEIGHTS
  for i = 0, #WEIGHTS - 1 do
    drawWeightRow(i, h)
  end
end

function drawToolbox()
  gfx.setColor(Color[Color.white])
  gfx.rectangle("fill", 0, 0, BOX_W - 1, BOX_H)
  gfx.setColor(Color[Color.white + Color.bright])
  gfx.rectangle("line", 0, 0, BOX_W - 1, BOX_H)
  drawTools()
  drawWeightSelector()
end

-- weight, target, frame

function getWeight()
  local aw = WEIGHTS[weight]
  if tool == ERASER then
    aw = aw * ERASER_SCALE
  end
  return aw
end

function drawTarget()
  local x, y = love.mouse.getPosition()
  if inCanvasRange(x, y) then
    gfx.setColor(Color[Color.white])
    gfx.circle("line", x, y, getWeight())
  end
end

function love.draw()
  drawBackground()
  drawToolbox()
  drawColorPalette()
  gfx.draw(canvas, BOX_W)
  drawTarget()
end

-- click handlers

function setColor(x, y, btn)
  local row = math.modf((HEIGHT - y) / BLOCK_H)
  local col = math.modf((x - SEL_W) / BLOCK_W)
  if btn == 1 then
    color = col + (PAL_COLS * row)
  elseif btn > 1 then
    bg_color = col + (PAL_COLS * row)
  end
end

function setTool(_, y)
  local h = ICON_D + M_4
  local sel = math.modf(y / h) + 1
  if sel <= N_T then
    tool = sel
  end
end

function setLineWeight(_, y)
  local ws = #WEIGHTS
  local h = WEIGHT_H / ws
  local lw = math.modf((y - WB_Y) / h) + 1
  if lw > 0 and lw <= ws then
    weight = lw
  end
end

function paintColor(btn)
  if btn == 1 and tool == BRUSH then
    return color
  end
  return bg_color
end

function onCanvas(btn, paint)
  local idx = paintColor(btn)
  canvas:renderTo(function()
    gfx.setColor(Color[idx])
    paint()
  end)
end

function stamp(cx, cy, aw)
  gfx.circle("fill", cx - BOX_W, cy, aw)
end

function useCanvas(x, y, btn)
  local aw = getWeight()
  onCanvas(btn, function()
    stamp(x, y, aw)
  end)
end

function paintStroke(px, py, x, y)
  local aw = getWeight()
  local ex = x - px
  local ey = y - py
  local len = math.sqrt(ex * ex + ey * ey)
  local n = math.ceil(len / (aw * STEP_FRAC))
  for i = 1, n do
    local t = i / n
    stamp(px + ex * t, py + ey * t, aw)
  end
end

function strokeCanvas(x, y, dx, dy)
  onCanvas(1, function()
    paintStroke(x - dx, y - dy, x, y)
  end)
end

REGIONS = {
  { inPaletteRange, setColor },
  { inCanvasRange, useCanvas },
  { inToolRange, setTool },
  { inWeightRange, setLineWeight },
}

function point(x, y, btn)
  for i = 1, #REGIONS do
    local r = REGIONS[i]
    if r[1](x, y) then
      r[2](x, y, btn)
    end
  end
end

function compy.singleclick(x, y)
  point(x, y, 1)
end

function compy.doubleclick(x, y)
  point(x, y, 2)
end

function love.mousemoved(x, y, dx, dy)
  if not inCanvasRange(x, y) then
    return
  end
  if love.mouse.isDown(1) then
    strokeCanvas(x, y, dx, dy)
  end
end

-- keyboard

function cycleTool()
  if tool >= N_T then
    tool = BRUSH
  else
    tool = tool + 1
  end
end

function weightDown()
  if weight > 1 then
    weight = weight - 1
  end
end

function weightUp()
  if weight < #WEIGHTS then
    weight = weight + 1
  end
end

KEYS = {
  tab = cycleTool,
  ['['] = weightDown,
  [']'] = weightUp,
}

function setColorKey(k)
  local c = COLORKEYS[k]
  if c then
    if Key.shift() then
      c = c + PAL_COLS
    end
    color = c
  end
end

function love.keypressed(k)
  local action = KEYS[k]
  if action then
    action()
  end
  setColorKey(k)
end
