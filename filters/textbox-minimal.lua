-- textbox-minimal.lua: Emit TextBoxMarker START/END around .textbox Divs.
--
-- Minimal extraction from next-gen-comp-paper/filters/jami-style.lua for
-- med-resist-grant. Only .textbox Divs get START/END markers; all other
-- blocks pass through unchanged (no JSEK本文 wrapping, no OrderedList
-- renumbering, no .grid handling).

if FORMAT ~= "docx" then
  return {}
end

--- XML-escape a string for safe inclusion inside <w:t>.
--- Must escape & first to avoid double-escaping subsequent substitutions.
local function xml_escape(s)
  return (s:gsub("&", "&amp;")
           :gsub("<", "&lt;")
           :gsub(">", "&gt;")
           :gsub('"', "&quot;")
           :gsub("'", "&apos;"))
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

--- Allowed enum values for string attributes (C11-02 whitelist).
local ENUMS = {
  ["anchor-h"]    = { page = true, margin = true, paragraph = true, column = true },
  ["anchor-v"]    = { page = true, margin = true, paragraph = true, line = true },
  ["wrap"]        = { tight = true, square = true, none = true },
  ["behind"]      = { ["true"] = true, ["false"] = true },
  ["valign"]      = { top = true, bottom = true, center = true },
  -- C 案: kind=table/mixed のとき wrap_textbox.py で適用する装飾。
  -- "minimal" は booktabs（上下線＋ヘッダ下線）、"bordered" はフルグリッド、
  -- "banded" はヘッダ網掛け＋上下線。"none" は装飾を入れず reference.docx の
  -- Table スタイルに完全に任せる（pre-C 案互換）。
  ["table-style"] = { minimal = true, bordered = true, banded = true, none = true },
}

--- Validate enum attribute; abort on unknown value.
local function check_enum(name, value)
  if ENUMS[name] and not ENUMS[name][value] then
    local allowed = {}
    for k, _ in pairs(ENUMS[name]) do table.insert(allowed, k) end
    io.stderr:write(string.format(
      "ERROR: .textbox attribute %s=\"%s\" is not one of {%s}\n",
      name, value, table.concat(allowed, ", ")))
    os.exit(1)
  end
end

--- Build a TextBoxMarker RawBlock with escaped attributes.
--- The paragraph AND run both carry <w:vanish/> so the marker
--- paragraph mark stays hidden even if the TextBoxMarker style
--- is not defined in reference.docx (M11-07).
local function textbox_marker(text)
  return pandoc.RawBlock("openxml",
    '<w:p><w:pPr><w:pStyle w:val="TextBoxMarker"/>' ..
    '<w:rPr><w:vanish/></w:rPr></w:pPr>' ..
    '<w:r><w:rPr><w:vanish/></w:rPr>' ..
    '<w:t xml:space="preserve">' .. xml_escape(text) .. '</w:t></w:r></w:p>')
end

--- Classify a .textbox Div's top-level content.
--- Returns one of "image", "table", "mixed" — where "mixed" means both a
--- Table and at least one non-Table block are present at the Div's top
--- level. Nested containers (BlockQuote, Div) are probed one level deep
--- so that a Table wrapped in a lightweight container still counts.
--- Used by wrap_textbox.py to decide whether to apply table-width
--- fitting. Defaults to "image" when the Div has no Table, which
--- preserves the pre-B 案 code path for all existing image textboxes.
local function classify_content(content)
  local has_table, has_other = false, false
  for _, c in ipairs(content) do
    if c.t == "Table" then
      has_table = true
    else
      has_other = true
      -- Probe one level deep for a Table wrapped in Div/BlockQuote.
      if c.content then
        for _, inner in ipairs(c.content) do
          if inner.t == "Table" then has_table = true end
        end
      end
    end
  end
  if has_table and has_other then return "mixed"
  elseif has_table then return "table"
  else return "image" end
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
  local kind = classify_content(div.content)
  -- C 案: table-style はユーザが明示したときだけ伝搬させ、
  -- 既定値の選択は wrap_textbox.py 側で kind に応じて行わせる。
  local table_style = attrs["table-style"]

  -- N11-02: reject empty-dimension textboxes up front.
  if width <= 0 or height <= 0 then
    io.stderr:write(string.format(
      "ERROR: .textbox requires positive width and height " ..
      "(got width=%d, height=%d from width=\"%s\" height=\"%s\")\n",
      width, height, tostring(attrs["width"]), tostring(attrs["height"])))
    os.exit(1)
  end

  -- C11-02: enforce enum whitelist before embedding values in OOXML.
  check_enum("anchor-h", anchor_h)
  check_enum("anchor-v", anchor_v)
  check_enum("wrap", wrap)
  check_enum("behind", behind)
  check_enum("valign", valign)
  if table_style then check_enum("table-style", table_style) end

  local params = string.format(
    "TEXTBOX_START:width=%d;height=%d;pos-x=%d;pos-y=%d;anchor-h=%s;anchor-v=%s;wrap=%s;behind=%s;valign=%s;kind=%s",
    width, height, pos_x, pos_y, anchor_h, anchor_v, wrap, behind, valign, kind)
  if page then
    params = params .. ";page=" .. page
  end
  if table_style then
    params = params .. ";table-style=" .. table_style
  end

  local result = pandoc.List()
  result:insert(textbox_marker(params))
  result:extend(div.content)
  result:insert(textbox_marker("TEXTBOX_END"))
  return result
end

--- Walk a single block recursively to detect a nested .textbox Div.
--- M11-04: if any remain below top level, abort loudly instead of
--- silently passing through.
local function has_nested_textbox(block)
  if block.t == "Div" and block.classes and block.classes:includes("textbox") then
    return true
  end
  -- Recurse into block containers. pandoc's walk descends into
  -- children for us when we wrap in a Div and call :walk{}.
  local found = false
  local probe = pandoc.Div({block})
  probe = probe:walk({
    Div = function(d)
      if d.classes and d.classes:includes("textbox") then
        found = true
      end
      return nil
    end,
  })
  return found
end

--- Walk top-level blocks, expanding .textbox Divs into marker-wrapped
--- sequences. Non-textbox blocks pass through untouched but are scanned
--- for orphan nested .textbox Divs to fail fast.
local function process_blocks(blocks)
  local result = pandoc.List()
  for _, block in ipairs(blocks) do
    if block.t == "Div" and block.classes:includes("textbox") then
      result:extend(process_textbox(block))
    else
      if has_nested_textbox(block) then
        io.stderr:write(
          "ERROR: .textbox Div found below document top level. " ..
          "textbox-minimal.lua only processes .textbox at the " ..
          "document root — move the Div out of its enclosing " ..
          "Blockquote/List/Div.\n")
        os.exit(1)
      end
      result:insert(block)
    end
  end
  return result
end

return {
  -- Pass 1: rewrite .svg image src to .svg.png so pandoc's primary blip
  -- is a PNG (avoids Word's unstable primary-blip-is-SVG behavior; the
  -- real SVG is re-attached later via asvg:svgBlob in wrap_textbox.py).
  -- N12-01: 拡張子は .svg（小文字）限定。大文字 / 混合ケースは Phase A の
  --         *.svg glob と整合しないため、silent に画像欠落 docx を作らない
  --         よう fail-fast する。
  { Image = function(img)
      local ext = img.src:match("%.[sS][vV][gG]$")
      if ext then
        if ext ~= ".svg" then
          io.stderr:write(string.format(
            "ERROR: SVG image '%s' uses non-lowercase extension '%s'. " ..
            "Rename the file (and the markdown reference) to '.svg' — " ..
            "Phase A globs are case-sensitive and will skip the file, " ..
            "causing pandoc to silently emit a docx without the image.\n",
            img.src, ext))
          os.exit(1)
        end
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
