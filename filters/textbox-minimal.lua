-- textbox-minimal.lua: Emit TextBoxMarker START/END around .textbox Divs.
--
-- Minimal extraction from next-gen-comp-paper/filters/jami-style.lua for
-- med-resist-grant. Only .textbox Divs get START/END markers; all other
-- blocks pass through unchanged (no JSEK本文 wrapping, no OrderedList
-- renumbering, no .grid handling).

if FORMAT ~= "docx" then
  return {}
end

--- Convert dimension string (e.g. "80mm", "300pt") to EMU.
--- 1mm = 36000 EMU, 1pt = 12700 EMU, 1cm = 360000 EMU, 1in = 914400 EMU.
local function to_emu(s)
  if not s then return 0 end
  local num, unit = s:match("^([%d%.]+)%s*(%a+)$")
  if not num then return tonumber(s) or 0 end
  num = tonumber(num)
  if unit == "mm" then return math.floor(num * 36000)
  elseif unit == "pt" then return math.floor(num * 12700)
  elseif unit == "cm" then return math.floor(num * 360000)
  elseif unit == "in" then return math.floor(num * 914400)
  elseif unit == "emu" then return math.floor(num)
  else return math.floor(num) end
end

--- Build a TextBoxMarker RawBlock with encoded attributes.
local function textbox_marker(text)
  return pandoc.RawBlock("openxml",
    '<w:p><w:pPr><w:pStyle w:val="TextBoxMarker"/></w:pPr>' ..
    '<w:r><w:rPr><w:vanish/></w:rPr>' ..
    '<w:t>' .. text .. '</w:t></w:r></w:p>')
end

--- Process a .textbox Div: emit START marker, content, END marker.
local function process_textbox(div)
  local attrs = div.attributes
  local width = to_emu(attrs["width"] or "0")
  local height = to_emu(attrs["height"] or "0")
  local pos_x = to_emu(attrs["pos-x"] or "0pt")
  local pos_y = to_emu(attrs["pos-y"] or "0pt")
  local anchor_h = attrs["anchor-h"] or "page"
  local anchor_v = attrs["anchor-v"] or "page"
  local wrap = attrs["wrap"] or "tight"
  local behind = attrs["behind"] or "false"
  local valign = attrs["valign"] or "top"
  local page = attrs["page"]

  local params = string.format(
    "TEXTBOX_START:width=%d;height=%d;pos-x=%d;pos-y=%d;anchor-h=%s;anchor-v=%s;wrap=%s;behind=%s;valign=%s",
    width, height, pos_x, pos_y, anchor_h, anchor_v, wrap, behind, valign)
  if page then
    params = params .. ";page=" .. page
  end

  local result = pandoc.List()
  result:insert(textbox_marker(params))
  result:extend(div.content)
  result:insert(textbox_marker("TEXTBOX_END"))
  return result
end

--- Walk top-level blocks, expanding .textbox Divs into marker-wrapped
--- sequences. Everything else passes through untouched.
local function process_blocks(blocks)
  local result = pandoc.List()
  for _, block in ipairs(blocks) do
    if block.t == "Div" and block.classes:includes("textbox") then
      result:extend(process_textbox(block))
    else
      result:insert(block)
    end
  end
  return result
end

return {
  -- Pass 1: rewrite .svg image src to .svg.png so pandoc's primary blip
  -- is a PNG (avoids Word's unstable primary-blip-is-SVG behavior; the
  -- real SVG is re-attached later via asvg:svgBlob in wrap_textbox.py).
  { Image = function(img)
      if img.src:match("%.svg$") then
        img.src = img.src .. ".png"
      end
      return img
    end
  },
  -- Pass 2: expand .textbox Divs into START/END markers.
  { Pandoc = function(doc)
      doc.blocks = process_blocks(doc.blocks)
      return doc
    end
  },
}
