-- objects.lua

-- Object model: the ordered list of objects is the picture's
-- source of truth; pixels are derived from it (spec). This
-- module is pure data — no drawing happens here.

objects = { }

-- the stroke currently being drawn

stroke = nil

-- the last cleared picture, kept for undo

cleared = nil

function beginStroke(x, y, c, w)
  stroke = {
    kind = "stroke",
    color = c,
    weight = w,
    pad = w,
    points = { }
  }
  stroke.x1 = x
  stroke.y1 = y
  stroke.x2 = x
  stroke.y2 = y
  strokePoint(x, y)
end

function strokePoint(x, y)
  local pts = stroke.points
  pts[#pts + 1] = x
  pts[#pts + 1] = y
  stroke.x1 = math.min(stroke.x1, x)
  stroke.y1 = math.min(stroke.y1, y)
  stroke.x2 = math.max(stroke.x2, x)
  stroke.y2 = math.max(stroke.y2, y)
end

function commitStroke()
  objects[#objects + 1] = stroke
  stroke = nil
  cleared = nil
end

function clearObjects()
  objects = { }
  stroke = nil
  cleared = nil
end

-- saves the array by reference: Lua tables are not
-- copied on assignment, and undo swaps it back

function clearPicture()
  cleared = objects
  objects = { }
end

-- depth 1 (spec): one step back -- restore the last clear,
-- otherwise drop the last object

function undo()
  if cleared then
    objects = cleared
    cleared = nil
  else
    objects[#objects] = nil
  end
end

function stickerBox(o, half)
  o.x1 = o.x - half
  o.y1 = o.y - half
  o.x2 = o.x + half
  o.y2 = o.y + half
end

function addSticker(id, x, y, half)
  cleared = nil
  local o = {
    kind = "sticker",
    id = id,
    x = x,
    y = y,
    scale = 1,
    pad = 0
  }
  stickerBox(o, half)
  objects[#objects + 1] = o
end

-- hit testing: a coarse bbox test, then a fine test per kind
-- (point-to-polyline for strokes), topmost object first (spec)

function clamp01(t)
  return math.max(0, math.min(1, t))
end

function inBBox(o, x, y, r)
  local pad = o.pad + r
  return o.x1 - pad <= x and x <= o.x2 + pad
       and o.y1 - pad <= y
       and y <= o.y2 + pad
end

-- squared distance from (x, y) to the segment ending at
-- point index i of the polyline

function segDist2(o, i, x, y)
  local pts = o.points
  local ax, ay = pts[i - 2], pts[i - 1]
  local ex = pts[i] - ax
  local ey = pts[i + 1] - ay
  local ll = ex * ex + ey * ey
  local t = 0
  if 0 < ll then
    t = clamp01(((x - ax) * ex + (y - ay) * ey) / ll)
  end
  local dx = x - (ax + ex * t)
  local dy = y - (ay + ey * t)
  return dx * dx + dy * dy
end

function hitDot(o, x, y, p2)
  local dx = x - o.points[1]
  local dy = y - o.points[2]
  return dx * dx + dy * dy <= p2
end

function hitStroke(o, x, y, r)
  local pad = o.weight + r
  local p2 = pad * pad
  local pts = o.points
  if #pts == 2 then
    return hitDot(o, x, y, p2)
  end
  for i = 3, #pts - 1, 2 do
    if segDist2(o, i, x, y) <= p2 then
      return true
    end
  end
  return false
end

-- for stickers the box itself is the fine test (spec)

function hitSticker()
  return true
end

HIT_OBJECT = {
  stroke = hitStroke,
  sticker = hitSticker
}

function hitObject(o, x, y, r)
  if not inBBox(o, x, y, r) then
    return false
  end
  return HIT_OBJECT[o.kind](o, x, y, r)
end

function topmostAt(x, y, r)
  for i = #objects, 1, -1 do
    if hitObject(objects[i], x, y, r) then
      return i
    end
  end
end

function removeObject(i)
  table.remove(objects, i)
end
