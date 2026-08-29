require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Typeface"
import "android.content.Intent"
import "android.content.Context"
import "android.content.ClipboardManager"
import "android.content.ClipData"
import "android.speech.RecognizerIntent"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "com.androlua.LuaDialog"
import "com.androlua.Http"
import "java.lang.String"
import "android.text.TextWatcher"

local activity = this

-- آپ کے گٹ ہب فولڈر کا ڈائریکٹ مین لنک (Base URL) پچھلے کوئز کے لیے
local BASE_URL = "https://raw.githubusercontent.com/tecno46-lang/competition/main/question%20answer%20data/"

-- وسائل بخشش کے ڈیٹا کا ڈائریکٹ مین لنک (Base URL)
local WASAIL_BASE_URL = "https://raw.githubusercontent.com/tecno46-lang/competition/main/naat/Wasail_e_Bakhshish/"

-- عجائب القرآن کی فائل کا ڈائریکٹ را (raw) لنک
local AJAIB_URL = "https://raw.githubusercontent.com/tecno46-lang/competition/main/ajaib_ul_quran_data/ajaib_ul_quran.json"

-- اللہ پاک کے ناموں کی فائل کا ڈائریکٹ را (raw) لنک
local ALLAH_NAMES_URL = "https://raw.githubusercontent.com/tecno46-lang/competition/main/Allah%20names/Allah%20names%20benefit.json"

-- آف لائن فائلوں کا پاتھ
local refFilePath = activity.getLuaDir() .. "/references.json"
local catFilePath = activity.getLuaDir() .. "/categories.json"
local wasailCatFilePath = activity.getLuaDir() .. "/wasail_categories.json"
local ajaibFilePath = activity.getLuaDir() .. "/ajaib_ul_quran.json"
local allahNamesFilePath = activity.getLuaDir() .. "/allah_names_benefit.json"
local ttsWarningPrefPath = activity.getLuaDir() .. "/hide_tts_warning.txt"

local referencesData = {}
local categoriesData = {}
local wasailCategoriesData = {}
local ajaibData = {}
local allahNamesData = {}

-- وسائل بخشش کا کیش (تاکہ یوزر کو انتظار نہ کرنا پڑے)
local wasailCache = {}

-- کلپ بورڈ پر کاپی کرنے کا فنکشن
local function copyToClipboard(text)
    local clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE)
    local clip = ClipData.newPlainText("Copied Text", text)
    clipboard.setPrimaryClip(clip)
    Toast.makeText(activity, "کاپی ہو گیا!", Toast.LENGTH_SHORT).show()
end

-- ==========================================
-- نیا "اسمارٹ اسپلٹ" (Smart Split) فنکشنز
-- ==========================================

-- الفاظ میں توڑنے کا فنکشن (Word Mode)
local function splitIntoWords(text)
    local t = {}
    for word in string.gmatch(text, "%S+") do
        table.insert(t, word)
    end
    return t
end

-- لائنوں میں توڑنے کا جدید فنکشن (Line Mode)
local function smartSplitIntoLines(text)
    -- اُردو کے اختتامی نشانات کو نئی لائن سے تبدیل کریں (تاکہ جملے ٹوٹ سکیں)
    local temp = text:gsub("۔", "۔\n"):gsub("؟", "؟\n"):gsub("!", "!\n")
    temp = temp:gsub("\r\n", "\n")
    
    local t = {}
    for line in string.gmatch(temp, "[^\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            -- اگر فل اسٹاپ نہ ہونے کی وجہ سے جملہ بہت لمبا ہو جائے، تو اسے 15، 15 الفاظ میں توڑیں
            if string.len(trimmed) > 300 then
                local words = splitIntoWords(trimmed)
                local chunk = {}
                for i, w in ipairs(words) do
                    table.insert(chunk, w)
                    if i % 15 == 0 or i == #words then
                        table.insert(t, table.concat(chunk, " "))
                        chunk = {}
                    end
                end
            else
                table.insert(t, trimmed)
            end
        end
    end
    return t
end

-- پیراگراف میں توڑنے کا جدید فنکشن (Paragraph Mode)
local function smartSplitIntoParagraphs(text)
    -- اگر ٹیکسٹ میں پہلے سے ڈبل لائنز (نعت کے بند) موجود ہیں تو انہیں استعمال کریں
    local countStanzas = select(2, text:gsub("\n\n", ""))
    if countStanzas > 1 then
        local t = {}
        local normalized = text:gsub("\r\n", "\n")
        for stanza in string.gmatch(normalized .. "\n\n", "(.-)\n\n") do
            local trimmed = stanza:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then table.insert(t, trimmed) end
        end
        return t
    else
        -- اگر یہ لمبا پیراگراف (عجائب القرآن) ہے تو جملوں کے حساب سے 3، 3 جملوں کا پیراگراف بنائیں
        local lines = smartSplitIntoLines(text)
        local t = {}
        local chunk = {}
        for i, s in ipairs(lines) do
            table.insert(chunk, s)
            if i % 3 == 0 or i == #lines then
                table.insert(t, table.concat(chunk, " "))
                chunk = {}
            end
        end
        return t
    end
end

-- ==========================================
-- بیک گراؤنڈ لوڈنگ فنکشنز
-- ==========================================

local function loadReferences()
    local file = io.open(refFilePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local cjson = require "cjson"
        local success, data = pcall(cjson.decode, content)
        if success and data then referencesData = data end
    end
    local refUrl = BASE_URL .. "references.json?t=" .. tostring(os.time())
    Http.get(refUrl, function(code, response)
        if code == 200 and response and response:match("%S") then
            local f = io.open(refFilePath, "w")
            if f then f:write(response) f:close() end
            local success, data = pcall(require("cjson").decode, response)
            if success and data then referencesData = data end
        end
    end)
end

local function loadCategories()
    local file = io.open(catFilePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local success, data = pcall(require("cjson").decode, content)
        if success and data then categoriesData = data end
    end
    local catUrl = BASE_URL .. "categories.json?t=" .. tostring(os.time())
    Http.get(catUrl, function(code, response)
        if code == 200 and response and response:match("%S") then
            local f = io.open(catFilePath, "w")
            if f then f:write(response) f:close() end
            local success, data = pcall(require("cjson").decode, response)
            if success and data then categoriesData = data end
        end
    end)
end

local function loadWasailCategories()
    local file = io.open(wasailCatFilePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local success, data = pcall(require("cjson").decode, content)
        if success and data then wasailCategoriesData = data end
    end
    local catUrl = WASAIL_BASE_URL .. "categories.json?t=" .. tostring(os.time())
    Http.get(catUrl, function(code, response)
        if code == 200 and response and response:match("%S") then
            local f = io.open(wasailCatFilePath, "w")
            if f then f:write(response) f:close() end
            local success, data = pcall(require("cjson").decode, response)
            if success and data then wasailCategoriesData = data end
        end
    end)
end

local function preloadSingleWasailFile(filename)
    local url = WASAIL_BASE_URL .. filename .. "?t=" .. tostring(os.time())
    Http.get(url, function(code, res)
        if code == 200 and res and res:match("%S") then
            local success, d = pcall(require("cjson").decode, res)
            if success then wasailCache[filename] = d end
        end
    end)
end

local function preloadAllWasailFiles()
    local files = {"hamd_o_munajat.json", "naat1.json", "naat2.json", "naat3.json", "manqabat.json", "salaam.json", "mutafarriq.json"}
    for _, fName in ipairs(files) do
        preloadSingleWasailFile(fName)
    end
end

local function loadAjaibData()
    local file = io.open(ajaibFilePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local success, data = pcall(require("cjson").decode, content)
        if success and data then ajaibData = data end
    end
    local url = AJAIB_URL .. "?t=" .. tostring(os.time())
    Http.get(url, function(code, response)
        if code == 200 and response and response:match("%S") then
            local f = io.open(ajaibFilePath, "w")
            if f then f:write(response) f:close() end
            local success, data = pcall(require("cjson").decode, response)
            if success and data then ajaibData = data end
        end
    end)
end

local function loadAllahNamesData()
    local file = io.open(allahNamesFilePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local success, data = pcall(require("cjson").decode, content)
        if success and data then allahNamesData = data end
    end
    local url = ALLAH_NAMES_URL .. "?t=" .. tostring(os.time())
    Http.get(url, function(code, response)
        if code == 200 and response and response:match("%S") then
            local f = io.open(allahNamesFilePath, "w")
            if f then f:write(response) f:close() end
            local success, data = pcall(require("cjson").decode, response)
            if success and data then allahNamesData = data end
        end
    end)
end

loadReferences()
loadCategories()
loadWasailCategories()
preloadAllWasailFiles()
loadAjaibData()
loadAllahNamesData()

local wordChangeTable = {
  ["اپ"] = "آپ", ["ام"] = "آم", ["اج"] = "آج", ["اتا"] = "آتا", ["کیٹگری"] = "کیٹیگری"
}
local function fixSpokenText(text)
  for k, v in pairs(wordChangeTable) do text = text:gsub("%f[%a]" .. k .. "%f[^%a]", v) end
  return text
end

local function startVoiceSearch(targetEditText)
    local recordIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    recordIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    recordIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ur-PK")
    local speechRecord = SpeechRecognizer.createSpeechRecognizer(activity)
    speechRecord.setRecognitionListener(RecognitionListener{
        onReadyForSpeech = function() Toast.makeText(activity, "Listening...", Toast.LENGTH_SHORT).show() end,
        onResults = function(results)
            local data = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if data and data.size() > 0 then
                if targetEditText ~= nil then targetEditText.setText(fixSpokenText(data.get(0))) end
                Toast.makeText(activity, "Text added", Toast.LENGTH_SHORT).show()
            end
            speechRecord.destroy()
        end,
        onError = function() Toast.makeText(activity, "Could not understand", Toast.LENGTH_SHORT).show() speechRecord.destroy() end
    })
    speechRecord.startListening(recordIntent)
end

-- ==========================================
-- کامن ریڈنگ موڈ فنکشن (View As کے لیے)
-- ==========================================

local function showReadingModeDialog(itemTitle, chunks, modeName)
    local rm_dlg = LuaDialog(activity)
    rm_dlg.setTitle(itemTitle .. " (" .. modeName .. ")")
    local rm_views = {}
    local rm_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { TextView, text = "نوٹ: کسی بھی حصے کو کاپی کرنے کے لیے اس پر سنگل کلک کریں۔", textSize = "14sp", textColor = "#E91E63", layout_marginBottom = "10dp" },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1,
            { LinearLayout, id = "chunk_container", orientation = "vertical", layout_width = "fill" }
        },
        { Button, id = "btn_rm_close", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    
    rm_dlg.setView(loadlayout(rm_layout, rm_views))
    
    for i, chunkText in ipairs(chunks) do
        local txt = TextView(activity)
        txt.setText(chunkText)
        txt.setTextSize(18)
        txt.setTextColor(0xFF333333)
        txt.setPadding(20, 20, 20, 20)
        
        local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        params.setMargins(0, 0, 0, 5)
        txt.setLayoutParams(params)
        
        txt.onClick = function()
            copyToClipboard(chunkText)
        end
        rm_views.chunk_container.addView(txt)
        
        local line = View(activity)
        line.setBackgroundColor(0xFFE0E0E0)
        line.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 2))
        rm_views.chunk_container.addView(line)
    end
    rm_views.btn_rm_close.onClick = function() rm_dlg.dismiss() end
    rm_dlg.show()
end

-- ==========================================
-- وسائل بخشش (نعتیہ کلام) کے ڈائیلاگز اور فنکشنز
-- ==========================================

local function showKalamDetailsDialog(itemTitle, poetName, lyricsText)
    local detail_dlg = LuaDialog(activity)
    local detail_views = {}
    local detail_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_kalam_title", text = itemTitle, textSize = "22sp", textColor = "#4CAF50", gravity = "center", layout_width = "fill", layout_marginBottom = "5dp" },
        { TextView, id = "tv_kalam_info", text = "شاعر: " .. (poetName or ""), textSize = "14sp", textColor = "#757575", gravity = "center", layout_width = "fill", layout_marginBottom = "15dp" },
        { ScrollView, layout_width = "fill", layout_weight = 1, 
            { LinearLayout, orientation = "vertical", layout_width = "fill",
                { TextView, text = lyricsText, textSize = "18sp", textColor = "#333333", layout_width = "fill", paddingBottom = "10dp", gravity = "center_horizontal" }
            }
        },
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginTop = "15dp",
            { Button, id = "btn_view_as", text = "View As", layout_width = "0dp", layout_weight = 1, backgroundColor = "#FF9800", textColor = "#FFFFFF", padding = "15dp", layout_marginRight = "5dp" },
            { Button, id = "btn_close_kalam", text = "Close", layout_width = "0dp", layout_weight = 1, backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp", layout_marginLeft = "5dp" }
        }
    }

    detail_dlg.setView(loadlayout(detail_layout, detail_views))
    detail_dlg.setCancelable(false)
    detail_views.tv_kalam_title.setTypeface(Typeface.DEFAULT_BOLD)

    detail_views.btn_view_as.onClick = function()
        local va_dlg = LuaDialog(activity)
        va_dlg.setTitle("پڑھنے کا انداز منتخب کریں")
        local va_views = {}
        local va_layout = {
            LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
            { Button, id = "btn_word", text = "WORD (لفظ)", layout_width = "fill", layout_marginBottom = "10dp", backgroundColor = "#FF9800", textColor = "#FFFFFF", padding = "15dp" },
            { Button, id = "btn_line", text = "LINE (لائن)", layout_width = "fill", layout_marginBottom = "10dp", backgroundColor = "#4CAF50", textColor = "#FFFFFF", padding = "15dp" },
            { Button, id = "btn_para", text = "PARAGRAPH (پیراگراف)", layout_width = "fill", layout_marginBottom = "10dp", backgroundColor = "#2196F3", textColor = "#FFFFFF", padding = "15dp" },
            { Button, id = "btn_cancel", text = "CANCEL", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
        }
        va_dlg.setView(loadlayout(va_layout, va_views))
        
        va_views.btn_word.onClick = function()
            va_dlg.dismiss()
            showReadingModeDialog(itemTitle, splitIntoWords(lyricsText), "Word Mode")
        end
        va_views.btn_line.onClick = function()
            va_dlg.dismiss()
            showReadingModeDialog(itemTitle, smartSplitIntoLines(lyricsText), "Line Mode")
        end
        va_views.btn_para.onClick = function()
            va_dlg.dismiss()
            showReadingModeDialog(itemTitle, smartSplitIntoParagraphs(lyricsText), "Paragraph Mode")
        end
        va_views.btn_cancel.onClick = function()
            va_dlg.dismiss()
        end
        
        va_dlg.show()
    end

    detail_views.btn_close_kalam.onClick = function() detail_dlg.dismiss() end
    detail_dlg.show()
end

local function showWasailListDialog(data, titleText)
    local list_dlg = LuaDialog(activity)
    list_dlg.setTitle(titleText)
    
    local list_views = {}
    local list_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "5dp", gravity = "center_vertical",
            { EditText, id = "et_search", hint = "Search kalam...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_voice", text = "VOICE SEARCH", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        { TextView, id = "tv_k_count", text = "Total Kalam: 0", textSize = "14sp", textColor = "#4CAF50", layout_width = "fill", layout_marginBottom = "10dp", gravity = "center" },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1, 
            { LinearLayout, id = "kalam_container", orientation = "vertical", layout_width = "fill" } 
        },
        { Button, id = "btn_close_list", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    
    list_dlg.setView(loadlayout(list_layout, list_views))
    list_views.btn_voice.onClick = function() startVoiceSearch(list_views.et_search) end

    local function populateList(query)
        list_views.kalam_container.removeAllViews()
        local count = 0
        for i, item in ipairs(data) do
            local title = item.title or ""
            local lyrics = item.lyrics or ""
            local poet = item.poet or ""
            if query == "" or string.find(title, query, 1, true) then
                count = count + 1
                local btn = Button(activity)
                local numberedTitle = tostring(count) .. "۔ " .. title
                btn.setText(numberedTitle)
                btn.setTextSize(16)
                btn.setPadding(20, 20, 20, 20)
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 10)
                btn.setLayoutParams(params)
                btn.setOnClickListener(function() showKalamDetailsDialog(numberedTitle, poet, lyrics) end)
                list_views.kalam_container.addView(btn)
            end
        end
        list_views.tv_k_count.setText("Total Kalam: " .. tostring(count))
    end
    populateList("")
    list_views.et_search.addTextChangedListener(TextWatcher{ onTextChanged = function(s) populateList(tostring(s)) end })
    list_views.btn_close_list.onClick = function() list_dlg.dismiss() end
    list_dlg.show()
end

local function fetchWasailCategoryData(filename, categoryName)
    if filename == "naat.json" then
        local allNaats = {}
        local filesToFetch = {"naat1.json", "naat2.json", "naat3.json"}
        local isAllCached = true
        for _, fName in ipairs(filesToFetch) do
            if not wasailCache[fName] then isAllCached = false break end
        end
        
        if isAllCached then
            for _, fName in ipairs(filesToFetch) do
                for _, item in ipairs(wasailCache[fName]) do table.insert(allNaats, item) end
            end
            showWasailListDialog(allNaats, categoryName)
        else
            Toast.makeText(activity, "Loading Naats...", Toast.LENGTH_SHORT).show()
            local completed = 0
            for _, fName in ipairs(filesToFetch) do
                Http.get(WASAIL_BASE_URL .. fName .. "?t=" .. tostring(os.time()), function(code, response)
                    completed = completed + 1
                    if code == 200 and response and response:match("%S") then
                        local s, d = pcall(require("cjson").decode, response)
                        if s then 
                            wasailCache[fName] = d
                            for _, item in ipairs(d) do table.insert(allNaats, item) end 
                        end
                    end
                    if completed == #filesToFetch then showWasailListDialog(allNaats, categoryName) end
                end)
            end
        end
    else
        if wasailCache[filename] then
            showWasailListDialog(wasailCache[filename], categoryName)
        else
            Toast.makeText(activity, "Please wait...", Toast.LENGTH_SHORT).show()
            Http.get(WASAIL_BASE_URL .. filename .. "?t=" .. tostring(os.time()), function(code, response)
                if code == 200 and response and response:match("%S") then
                    local s, d = pcall(require("cjson").decode, response)
                    if s then 
                        wasailCache[filename] = d
                        showWasailListDialog(d, categoryName) 
                    end
                else
                    Toast.makeText(activity, "فائل دستیاب نہیں", Toast.LENGTH_SHORT).show()
                end
            end)
        end
    end
end

local function showWasailSubMenu()
    if #wasailCategoriesData == 0 then
        Toast.makeText(activity, "کیٹیگریز لوڈ ہو رہی ہیں...", Toast.LENGTH_SHORT).show()
        loadWasailCategories()
        return
    end

    local cat_dlg = LuaDialog(activity)
    cat_dlg.setTitle("کیٹیگری منتخب کریں")
    local cat_views = {}
    local cat_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { TextView, id = "tv_total_cats", text = "Total Categories: " .. tostring(#wasailCategoriesData), textSize = "14sp", textColor = "#4CAF50", layout_width = "fill", layout_marginBottom = "10dp", gravity = "center" },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1, 
            { LinearLayout, id = "wasail_cat_container", orientation = "vertical", layout_width = "fill" } 
        },
        { Button, id = "btn_close_wasail_cat", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    cat_dlg.setView(loadlayout(cat_layout, cat_views))
    
    local count = 0
    for i, item in ipairs(wasailCategoriesData) do
        count = count + 1
        local catName = tostring(count) .. "۔ " .. item.name
        local btn = Button(activity)
        btn.setText(catName)
        btn.setTextSize(16)
        btn.setPadding(20, 20, 20, 20)
        local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        params.setMargins(0, 0, 0, 10)
        btn.setLayoutParams(params)
        
        btn.setOnClickListener(function() fetchWasailCategoryData(item.file, item.name) end)
        cat_views.wasail_cat_container.addView(btn)
    end
    cat_views.btn_close_wasail_cat.onClick = function() cat_dlg.dismiss() end
    cat_dlg.show()
end

local function showNaatiyaKalamSubMenu()
    local nk_dlg = LuaDialog(activity)
    nk_dlg.setTitle("Naatiya Kalam")
    local nk_views = {}
    local nk_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { Button, id = "btn_wasail_e_bakhshish", text = "WASAIL E BAKHSHISH", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#4CAF50", textColor = "#FFFFFF", padding = "15dp" },
        { Button, id = "btn_back", text = "Back", layout_width = "fill", layout_marginTop = "15dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    nk_dlg.setView(loadlayout(nk_layout, nk_views))
    nk_dlg.setCancelable(false)
    nk_views.btn_wasail_e_bakhshish.onClick = function() showWasailSubMenu() end
    nk_views.btn_back.onClick = function() nk_dlg.dismiss() end
    nk_dlg.show()
end

-- ==========================================
-- دلچسپ معلومات (QA)
-- ==========================================

local function showQuestionDetailsDialog(itemTitle, itemDetails, refText)
    local detail_dlg = LuaDialog(activity)
    local detail_views = {}
    local detail_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_q_title", text = itemTitle, textSize = "20sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "15dp" },
        { ScrollView, layout_width = "fill", layout_weight = 1, 
            { LinearLayout, orientation = "vertical", layout_width = "fill",
                { TextView, text = itemDetails, textSize = "18sp", textColor = "#333333", layout_width = "fill", paddingBottom = "10dp" },
                { TextView, id = "tv_ref", text = "", textSize = "14sp", textColor = "#757575", layout_width = "fill", paddingTop = "10dp" }
            }
        },
        -- دلچسپ معلومات سے View As کا بٹن ہٹا دیا گیا ہے، صرف Close بٹن باقی ہے
        { Button, id = "btn_close", text = "Close", layout_width = "fill", layout_marginTop = "15dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    detail_dlg.setView(loadlayout(detail_layout, detail_views))
    detail_dlg.setCancelable(false)
    detail_views.tv_q_title.setTypeface(Typeface.DEFAULT_BOLD)
    
    if refText and refText ~= "" then 
        detail_views.tv_ref.setText("حوالہ: " .. refText) 
    else 
        detail_views.tv_ref.setVisibility(View.GONE) 
    end

    detail_views.btn_close.onClick = function() detail_dlg.dismiss() end
    detail_dlg.show()
end

local function showQuestionsListDialog(data, titleText, catKey)
    local list_dlg = LuaDialog(activity)
    list_dlg.setTitle(titleText)
    local list_views = {}
    local list_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "5dp", gravity = "center_vertical",
            { EditText, id = "et_search", hint = "Search question...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_voice", text = "VOICE SEARCH", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        { TextView, id = "tv_q_count", text = "Total Questions: 0", textSize = "14sp", textColor = "#4CAF50", layout_width = "fill", layout_marginBottom = "10dp", gravity = "center" },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1, 
            { LinearLayout, id = "questions_container", orientation = "vertical", layout_width = "fill" } 
        },
        { Button, id = "btn_close_list", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    list_dlg.setView(loadlayout(list_layout, list_views))
    list_views.btn_voice.onClick = function() startVoiceSearch(list_views.et_search) end
    local items = data.qa_list or data

    local function populateList(query)
        list_views.questions_container.removeAllViews()
        local count = 0
        for i, item in ipairs(items) do
            local title = item.question or item.title or ""
            local details = item.answer or item.details or ""
            if query == "" or string.find(title, query, 1, true) then
                count = count + 1
                local btn = Button(activity)
                local originalTitle = title:gsub("%[.-%]", ""):gsub("%(start_span%)", ""):gsub("%(end_span%)", "")
                local cleanTitle = originalTitle:gsub("سوال نمبر %d+[%:۔%-]?%s*", "")
                local numberedTitle = tostring(count) .. "۔ " .. cleanTitle
                local qKey = catKey .. "_Q" .. tostring(i)
                local refText = referencesData[qKey] or ""
                btn.setText(numberedTitle)
                btn.setTextSize(16)
                btn.setPadding(20, 20, 20, 20)
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 10)
                btn.setLayoutParams(params)
                btn.setOnClickListener(function() showQuestionDetailsDialog(numberedTitle, details, refText) end)
                list_views.questions_container.addView(btn)
            end
        end
        list_views.tv_q_count.setText("Total Questions: " .. tostring(count))
    end
    populateList("")
    list_views.et_search.addTextChangedListener(TextWatcher{ onTextChanged = function(s) populateList(tostring(s)) end })
    list_views.btn_close_list.onClick = function() list_dlg.dismiss() end
    list_dlg.show()
end

local function fetchCategoryData(filename, categoryName, catKey)
    Toast.makeText(activity, "Please wait...", Toast.LENGTH_SHORT).show()
    local url = BASE_URL .. filename .. "?t=" .. tostring(os.time())
    Http.get(url, function(code, response)
        if code == 200 and response and response:match("%S") then
            local success, data = pcall(require("cjson").decode, response)
            if success and data then showQuestionsListDialog(data, categoryName, catKey) end
        else
            Toast.makeText(activity, "فائل دستیاب نہیں", Toast.LENGTH_SHORT).show()
        end
    end)
end

local function showQASubMenu()
    if #categoriesData == 0 then
        Toast.makeText(activity, "کیٹیگریز لوڈ ہو رہی ہیں...", Toast.LENGTH_SHORT).show()
        loadCategories()
        return
    end
    local cat_dlg = LuaDialog(activity)
    cat_dlg.setTitle("کیٹیگری منتخب کریں")
    local cat_views = {}
    local cat_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "5dp", gravity = "center_vertical",
            { EditText, id = "et_cat_search", hint = "Search category...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_cat_voice", text = "VOICE SEARCH", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        { TextView, id = "tv_cat_count", text = "Total Categories: 0", textSize = "14sp", textColor = "#4CAF50", layout_width = "fill", layout_marginBottom = "10dp", gravity = "center" },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1, 
            { LinearLayout, id = "cat_container", orientation = "vertical", layout_width = "fill" } 
        },
        { Button, id = "btn_close_cat", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    cat_dlg.setView(loadlayout(cat_layout, cat_views))
    cat_views.btn_cat_voice.onClick = function() startVoiceSearch(cat_views.et_cat_search) end
    
    local function populateCatList(query)
        cat_views.cat_container.removeAllViews()
        local count = 0
        local qStr = query:lower()
        for i, item in ipairs(categoriesData) do
            local catName = tostring(i) .. "۔ " .. item.name .. " (" .. item.roman .. ")"
            if query == "" or string.find(catName:lower(), qStr, 1, true) then
                count = count + 1
                local btn = Button(activity)
                btn.setText(catName)
                btn.setTextSize(16)
                btn.setPadding(20, 20, 20, 20)
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 10)
                btn.setLayoutParams(params)
                local catKey = item.file:gsub("%.json", "")
                btn.setOnClickListener(function() fetchCategoryData(item.file, item.name .. " (" .. item.roman .. ")", catKey) end)
                cat_views.cat_container.addView(btn)
            end
        end
        cat_views.tv_cat_count.setText("Total Categories: " .. tostring(count))
    end
    populateCatList("")
    cat_views.et_cat_search.addTextChangedListener(TextWatcher{ onTextChanged = function(s) populateCatList(tostring(s)) end })
    cat_views.btn_close_cat.onClick = function() cat_dlg.dismiss() end
    cat_dlg.show()
end

local function showStoryDetailsDialog(itemTitle, itemDetails)
    local detail_dlg = LuaDialog(activity)
    local detail_views = {}
    local detail_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_q_title", text = itemTitle, textSize = "20sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "15dp" },
        { ScrollView, layout_width = "fill", layout_weight = 1, 
            { LinearLayout, orientation = "vertical", layout_width = "fill",
                { TextView, text = itemDetails, textSize = "18sp", textColor = "#333333", layout_width = "fill", paddingBottom = "10dp" }
            }
        },
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginTop = "15dp",
            { Button, id = "btn_view_as", text = "View As", layout_width = "0dp", layout_weight = 1, backgroundColor = "#FF9800", textColor = "#FFFFFF", padding = "15dp", layout_marginRight = "5dp" },
            { Button, id = "btn_close", text = "Close", layout_width = "0dp", layout_weight = 1, backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp", layout_marginLeft = "5dp" }
        }
    }
    detail_dlg.setView(loadlayout(detail_layout, detail_views))
    detail_dlg.setCancelable(false)
    detail_views.tv_q_title.setTypeface(Typeface.DEFAULT_BOLD)

    detail_views.btn_view_as.onClick = function()
        local va_dlg = LuaDialog(activity)
        va_dlg.setTitle("پڑھنے کا انداز منتخب کریں")
        local va_views = {}
        local va_layout = {
            LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
            { Button, id = "btn_word", text = "WORD (لفظ)", layout_width = "fill", layout_marginBottom = "10dp", backgroundColor = "#FF9800", textColor = "#FFFFFF", padding = "15dp" },
            { Button, id = "btn_line", text = "LINE (لائن)", layout_width = "fill", layout_marginBottom = "10dp", backgroundColor = "#4CAF50", textColor = "#FFFFFF", padding = "15dp" },
            { Button, id = "btn_para", text = "PARAGRAPH (پیراگراف)", layout_width = "fill", layout_marginBottom = "10dp", backgroundColor = "#2196F3", textColor = "#FFFFFF", padding = "15dp" },
            { Button, id = "btn_cancel", text = "CANCEL", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
        }
        va_dlg.setView(loadlayout(va_layout, va_views))
        
        va_views.btn_word.onClick = function()
            va_dlg.dismiss()
            showReadingModeDialog(itemTitle, splitIntoWords(itemDetails), "Word Mode")
        end
        va_views.btn_line.onClick = function()
            va_dlg.dismiss()
            showReadingModeDialog(itemTitle, smartSplitIntoLines(itemDetails), "Line Mode")
        end
        va_views.btn_para.onClick = function()
            va_dlg.dismiss()
            showReadingModeDialog(itemTitle, smartSplitIntoParagraphs(itemDetails), "Paragraph Mode")
        end
        va_views.btn_cancel.onClick = function()
            va_dlg.dismiss()
        end
        va_dlg.show()
    end

    detail_views.btn_close.onClick = function() detail_dlg.dismiss() end
    detail_dlg.show()
end

local function showAjaibUlQuranList(data)
    local list_dlg = LuaDialog(activity)
    list_dlg.setTitle("عجائب القرآن مع غرائب القرآن")
    local list_views = {}
    local list_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "5dp", gravity = "center_vertical",
            { EditText, id = "et_search", hint = "Search story...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_voice", text = "VOICE SEARCH", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        { TextView, id = "tv_q_count", text = "Total Stories: 0", textSize = "14sp", textColor = "#4CAF50", layout_width = "fill", layout_marginBottom = "10dp", gravity = "center" },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1, 
            { LinearLayout, id = "stories_container", orientation = "vertical", layout_width = "fill" } 
        },
        { Button, id = "btn_close_list", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    list_dlg.setView(loadlayout(list_layout, list_views))
    list_views.btn_voice.onClick = function() startVoiceSearch(list_views.et_search) end

    local function populateList(query)
        list_views.stories_container.removeAllViews()
        local count = 0
        for i, item in ipairs(data) do
            local title = item.title or ""
            local details = item.details or ""
            if query == "" or string.find(title, query, 1, true) then
                count = count + 1
                local btn = Button(activity)
                local numberedTitle = tostring(count) .. "۔ " .. title
                btn.setText(numberedTitle)
                btn.setTextSize(16)
                btn.setPadding(20, 20, 20, 20)
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 10)
                btn.setLayoutParams(params)
                btn.setOnClickListener(function() showStoryDetailsDialog(numberedTitle, details) end)
                list_views.stories_container.addView(btn)
            end
        end
        list_views.tv_q_count.setText("Total Stories: " .. tostring(count))
    end
    populateList("")
    list_views.et_search.addTextChangedListener(TextWatcher{ onTextChanged = function(s) populateList(tostring(s)) end })
    list_views.btn_close_list.onClick = function() list_dlg.dismiss() end
    list_dlg.show()
end

local function openAjaibQuran()
    if ajaibData and #ajaibData > 0 then showAjaibUlQuranList(ajaibData) else Toast.makeText(activity, "Loading...", Toast.LENGTH_SHORT).show() loadAjaibData() end
end

-- ==========================================
-- اللہ کے ناموں کی لسٹ 
-- ==========================================

local function showAllahNamesList(data)
    local list_dlg = LuaDialog(activity)
    list_dlg.setTitle("Allah Names Benefit")
    local list_views = {}
    local list_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "5dp", gravity = "center_vertical",
            { EditText, id = "et_search", hint = "Search name...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_voice", text = "VOICE SEARCH", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        { TextView, id = "tv_count", text = "Total Names: 0", textSize = "14sp", textColor = "#4CAF50", layout_width = "fill", layout_marginBottom = "5dp", gravity = "center" },
        { TextView, text = "نوٹ: کسی بھی نام اور اس کے فائدے کو کاپی کرنے کے لیے نیچے جواب پر سنگل کلک کریں۔", textSize = "14sp", textColor = "#E91E63", layout_width = "fill", layout_marginBottom = "10dp", gravity = "center" },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1, 
            { LinearLayout, id = "names_container", orientation = "vertical", layout_width = "fill" } 
        },
        { Button, id = "btn_close_list", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    list_dlg.setView(loadlayout(list_layout, list_views))
    list_views.btn_voice.onClick = function() startVoiceSearch(list_views.et_search) end

    local function populateList(query)
        list_views.names_container.removeAllViews()
        local count = 0
        for i, item in ipairs(data) do
            local nameText = item.name or ""
            local benefitText = item.benefit or ""
            if query == "" or string.find(nameText, query, 1, true) then
                count = count + 1
                local itemContainer = LinearLayout(activity)
                itemContainer.setOrientation(LinearLayout.VERTICAL)
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 25)
                itemContainer.setLayoutParams(params)
                
                local fullTitle = tostring(count) .. "۔ " .. nameText
                local tvName = TextView(activity)
                tvName.setText(fullTitle)
                tvName.setTextSize(20)
                tvName.setTextColor(0xFF2196F3) 
                tvName.setTypeface(Typeface.DEFAULT_BOLD)
                
                local tvBenefit = TextView(activity)
                tvBenefit.setText(benefitText)
                tvBenefit.setTextSize(16)
                tvBenefit.setTextColor(0xFF333333) 
                tvBenefit.setPadding(0, 10, 0, 0)
                
                -- نمبر کو ہٹا کر واضح فارمیٹ میں کاپی کرنا
                tvBenefit.onClick = function()
                    local fullTextToCopy = nameText .. "\n" .. benefitText
                    copyToClipboard(fullTextToCopy)
                end
                
                itemContainer.addView(tvName)
                itemContainer.addView(tvBenefit)
                local line = View(activity)
                line.setBackgroundColor(0xFFE0E0E0)
                local lineParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 2)
                lineParams.setMargins(0, 20, 0, 0)
                line.setLayoutParams(lineParams)
                itemContainer.addView(line)
                list_views.names_container.addView(itemContainer)
            end
        end
        list_views.tv_count.setText("Total Results: " .. tostring(count))
    end
    populateList("")
    list_views.et_search.addTextChangedListener(TextWatcher{ onTextChanged = function(s) populateList(tostring(s)) end })
    list_views.btn_close_list.onClick = function() list_dlg.dismiss() end
    list_dlg.show()
end

local function openAllahNames()
    if allahNamesData and #allahNamesData > 0 then showAllahNamesList(allahNamesData) else Toast.makeText(activity, "Loading...", Toast.LENGTH_SHORT).show() loadAllahNamesData() end
end

-- ==========================================
-- مین سکرین
-- ==========================================

local function showQuizMainDialog()
    local dlg = LuaDialog(activity)
    local layout_views = {}
    local main_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_title", text = "Islamic Hub", textSize = "24sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "5dp" },
        { TextView, text = "project by Learning With Gulab", textSize = "14sp", textColor = "#607D8B", gravity = "center", layout_width = "fill", layout_marginBottom = "25dp" },
        { Button, id = "btn_qa", text = "Dilchasp Malomaat (Sawalan Jawaban)", layout_width = "fill", layout_marginTop = "5dp", padding = "15dp", backgroundColor = "#009688", textColor = "#FFFFFF" },
        { Button, id = "btn_ajaib", text = "Ajaib ul Quran", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#FF9800", textColor = "#FFFFFF", padding = "15dp" },
        { Button, id = "btn_allah_names", text = "Allah names benefit", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9C27B0", textColor = "#FFFFFF", padding = "15dp" },
        { Button, id = "btn_naatiya_kalam", text = "NAATIYA KALAM", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#4CAF50", textColor = "#FFFFFF", padding = "15dp" },
        { Button, id = "btn_exit", text = "Exit", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#F44336", textColor = "#FFFFFF", padding = "15dp" }
    }

    dlg.setView(loadlayout(main_layout, layout_views))
    dlg.setCancelable(false)
    layout_views.tv_title.setTypeface(Typeface.DEFAULT_BOLD)

    layout_views.btn_qa.onClick = function() showQASubMenu() end
    layout_views.btn_ajaib.onClick = function() openAjaibQuran() end
    layout_views.btn_allah_names.onClick = function() openAllahNames() end
    layout_views.btn_naatiya_kalam.onClick = function() showNaatiyaKalamSubMenu() end
    layout_views.btn_exit.onClick = function() dlg.dismiss() end

    dlg.show()
end

local function showTTSWarningDialog(onCompleteCallback)
    local file = io.open(ttsWarningPrefPath, "r")
    if file then
        file:close()
        onCompleteCallback()
        return
    end

    local dlg = LuaDialog(activity)
    dlg.setTitle("Important Notice")
    dlg.setCancelable(false)
    local warning_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, text = "Before using this extension, please ensure that you have downloaded and configured Arabic and Urdu language voices in your TTS engine. This will allow you to use it effectively and understand the written content properly.\n\nThank you.", textSize = "16sp", textColor = "#333333", layout_marginBottom = "20dp" },
        { CheckBox, id = "cb_dont_show", text = "Don't show again", textSize = "16sp", textColor = "#424242", layout_marginBottom = "20dp" },
        { Button, id = "btn_ok", text = "OK", layout_width = "fill", backgroundColor = "#2196F3", textColor = "#FFFFFF", padding = "15dp" }
    }
    
    local views = {}
    dlg.setView(loadlayout(warning_layout, views))
    views.btn_ok.onClick = function()
        if views.cb_dont_show.isChecked() then
            local f = io.open(ttsWarningPrefPath, "w")
            if f then f:write("true") f:close() end
        end
        dlg.dismiss()
        onCompleteCallback()
    end
    dlg.show()
end

showTTSWarningDialog(function() showQuizMainDialog() end)