require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Typeface"
import "android.content.Intent"
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

-- عجائب القرآن کی فائل کا ڈائریکٹ را (raw) لنک
local AJAIB_URL = "https://raw.githubusercontent.com/tecno46-lang/competition/main/ajaib_ul_quran_data/ajaib_ul_quran.json"

-- آف لائن فائلوں کا پاتھ
local refFilePath = activity.getLuaDir() .. "/references.json"
local catFilePath = activity.getLuaDir() .. "/categories.json"
local ajaibFilePath = activity.getLuaDir() .. "/ajaib_ul_quran.json"

local referencesData = {}
local categoriesData = {}
local ajaibData = {}

-- حوالے (References) لوڈ کرنے کا فنکشن
local function loadReferences()
    local file = io.open(refFilePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local cjson = require "cjson"
        local success, data = pcall(cjson.decode, content)
        if success and data then
            referencesData = data
        end
    end
    
    local refUrl = BASE_URL .. "references.json?t=" .. tostring(os.time())
    Http.get(refUrl, function(code, response)
        if code == 200 and response and response:match("%S") then
            local f = io.open(refFilePath, "w")
            if f then
                f:write(response)
                f:close()
                local cjson = require "cjson"
                local success, data = pcall(cjson.decode, response)
                if success and data then
                    referencesData = data
                end
            end
        end
    end)
end

-- کیٹیگریز لسٹ (Categories) لوڈ کرنے کا فنکشن
local function loadCategories()
    local file = io.open(catFilePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local cjson = require "cjson"
        local success, data = pcall(cjson.decode, content)
        if success and data then
            categoriesData = data
        end
    end
    
    local catUrl = BASE_URL .. "categories.json?t=" .. tostring(os.time())
    Http.get(catUrl, function(code, response)
        if code == 200 and response and response:match("%S") then
            local f = io.open(catFilePath, "w")
            if f then
                f:write(response)
                f:close()
                local cjson = require "cjson"
                local success, data = pcall(cjson.decode, response)
                if success and data then
                    categoriesData = data
                end
            end
        end
    end)
end

-- عجائب القرآن کا ڈیٹا بیک گراؤنڈ میں لوڈ کرنے کا نیا فنکشن
local function loadAjaibData()
    local file = io.open(ajaibFilePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local cjson = require "cjson"
        local success, data = pcall(cjson.decode, content)
        if success and data then
            ajaibData = data
        end
    end
    
    local url = AJAIB_URL .. "?t=" .. tostring(os.time())
    Http.get(url, function(code, response)
        if code == 200 and response and response:match("%S") then
            local f = io.open(ajaibFilePath, "w")
            if f then
                f:write(response)
                f:close()
                local cjson = require "cjson"
                local success, data = pcall(cjson.decode, response)
                if success and data then
                    ajaibData = data
                end
            end
        end
    end)
end

-- ایپ کھلتے ہی تینوں فائلیں بیک گراؤنڈ میں لوڈ کریں
loadReferences()
loadCategories()
loadAjaibData()

-- درست الفاظ کی فہرست (وائس سرچ کے لیے)
local wordChangeTable = {
  ["اپ"] = "آپ",
  ["ام"] = "آم",
  ["اج"] = "آج",
  ["اتا"] = "آتا",
  ["کیٹگری"] = "کیٹیگری"
}

local function fixSpokenText(text)
  for k, v in pairs(wordChangeTable) do
    text = text:gsub("%f[%a]" .. k .. "%f[^%a]", v)
  end
  return text
end

-- وائس سرچ کا فنکشن
local function startVoiceSearch(targetEditText)
    local recordIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    recordIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    recordIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ur-PK")

    local speechRecord = SpeechRecognizer.createSpeechRecognizer(activity)
    speechRecord.setRecognitionListener(RecognitionListener{
        onReadyForSpeech = function() 
            Toast.makeText(activity, "Listening...", Toast.LENGTH_SHORT).show()
        end,
        onResults = function(results)
            local data = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if data and data.size() > 0 then
                local spokenText = data.get(0)
                spokenText = fixSpokenText(spokenText)
                if targetEditText ~= nil then
                    targetEditText.setText(spokenText)
                end
                Toast.makeText(activity, "Text added", Toast.LENGTH_SHORT).show()
            end
            speechRecord.destroy()
        end,
        onError = function()
            Toast.makeText(activity, "Could not understand", Toast.LENGTH_SHORT).show()
            speechRecord.destroy()
        end
    })

    speechRecord.startListening(recordIntent)
end

-- کوئز کے سوال اور جواب دکھانے والا ڈائیلاگ
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

-- کوئز کی لسٹ دکھانے والا ڈائیلاگ
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

    list_views.btn_voice.onClick = function()
        startVoiceSearch(list_views.et_search)
    end

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
                
                btn.setOnClickListener(function()
                    showQuestionDetailsDialog(numberedTitle, details, refText)
                end)
                
                list_views.questions_container.addView(btn)
            end
        end
        list_views.tv_q_count.setText("Total Questions: " .. tostring(count))
    end

    populateList("")

    list_views.et_search.addTextChangedListener(TextWatcher{
        onTextChanged = function(s, start, before, count)
            populateList(tostring(s))
        end
    })
    
    list_views.btn_close_list.onClick = function() list_dlg.dismiss() end
    list_dlg.show()
end

local function fetchCategoryData(filename, categoryName, catKey)
    Toast.makeText(activity, "Please wait...", Toast.LENGTH_SHORT).show()
    
    local url = BASE_URL .. filename .. "?t=" .. tostring(os.time())
    
    Http.get(url, function(code, response)
        if code == 200 and response and response:match("%S") then
            local cjson = require "cjson"
            local success, data = pcall(cjson.decode, response)
            if success and data then
                showQuestionsListDialog(data, categoryName, catKey)
            else
                local dlg = LuaDialog(activity)
                dlg.setTitle("Error")
                dlg.setMessage("اس فائل کا فارمیٹ خراب ہے۔ بریکٹ یا کوما مسنگ ہے۔")
                dlg.setButton("OK", function() dlg.dismiss() end)
                dlg.show()
            end
        else
            local dlg = LuaDialog(activity)
            dlg.setTitle("Not Found")
            dlg.setMessage("یہ فائل ابھی دستیاب نہیں ہے۔\n\nفائل کا نام: " .. filename)
            dlg.setButton("OK", function() dlg.dismiss() end)
            dlg.show()
        end
    end)
end

local function showQASubMenu()
    if #categoriesData == 0 then
        Toast.makeText(activity, "کیٹیگریز لوڈ ہو رہی ہیں، براہِ کرم انٹرنیٹ چیک کریں...", Toast.LENGTH_SHORT).show()
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
    
    cat_views.btn_cat_voice.onClick = function()
        startVoiceSearch(cat_views.et_cat_search)
    end
    
    local function populateCatList(query)
        cat_views.cat_container.removeAllViews()
        local count = 0
        local qStr = query:lower()

        for i, item in ipairs(categoriesData) do
            local catName = tostring(i) .. "۔ " .. item.name .. " (" .. item.roman .. ")"
            local searchStr = catName:lower()

            if query == "" or string.find(searchStr, qStr, 1, true) then
                count = count + 1
                local btn = Button(activity)
                btn.setText(catName)
                btn.setTextSize(16)
                btn.setPadding(20, 20, 20, 20)
                
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 10)
                btn.setLayoutParams(params)
                
                local catKey = item.file:gsub("%.json", "")
                
                btn.setOnClickListener(function()
                    fetchCategoryData(item.file, item.name .. " (" .. item.roman .. ")", catKey)
                end)
                
                cat_views.cat_container.addView(btn)
            end
        end
        cat_views.tv_cat_count.setText("Total Categories: " .. tostring(count))
    end

    populateCatList("")

    cat_views.et_cat_search.addTextChangedListener(TextWatcher{
        onTextChanged = function(s, start, before, count)
            populateCatList(tostring(s))
        end
    })

    cat_views.btn_close_cat.onClick = function() cat_dlg.dismiss() end
    cat_dlg.show()
end


-- عجائب القرآن کے واقعے کی تفصیل دکھانے کے لیے
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
        { Button, id = "btn_close", text = "Close", layout_width = "fill", layout_marginTop = "15dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }

    detail_dlg.setView(loadlayout(detail_layout, detail_views))
    detail_dlg.setCancelable(false)
    detail_views.tv_q_title.setTypeface(Typeface.DEFAULT_BOLD)

    detail_views.btn_close.onClick = function() detail_dlg.dismiss() end
    detail_dlg.show()
end

-- عجائب القرآن کی لسٹ دکھانے کے لیے
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

    list_views.btn_voice.onClick = function()
        startVoiceSearch(list_views.et_search)
    end

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
                
                btn.setOnClickListener(function()
                    showStoryDetailsDialog(numberedTitle, details)
                end)
                
                list_views.stories_container.addView(btn)
            end
        end
        list_views.tv_q_count.setText("Total Stories: " .. tostring(count))
    end

    populateList("")

    list_views.et_search.addTextChangedListener(TextWatcher{
        onTextChanged = function(s, start, before, count)
            populateList(tostring(s))
        end
    })
    
    list_views.btn_close_list.onClick = function() list_dlg.dismiss() end
    list_dlg.show()
end

-- پری لوڈڈ ڈیٹا چیک کرنے اور ڈائیلاگ کھولنے کا فنکشن
local function openAjaibQuran()
    if ajaibData and #ajaibData > 0 then
        showAjaibUlQuranList(ajaibData)
    else
        Toast.makeText(activity, "عجائب القرآن کا ڈیٹا لوڈ ہو رہا ہے، براہِ کرم انٹرنیٹ چیک کریں...", Toast.LENGTH_SHORT).show()
        loadAjaibData() -- اگر ڈیٹا نہ ہو تو دوبارہ فیچ کرنے کی کوشش
    end
end

-- مین سکرین ڈائیلاگ
function showQuizMainDialog()
    local dlg = LuaDialog(activity)
    
    local layout_views = {}
    local main_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_title", text = "Zehni Azmaish Season 3", textSize = "24sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "5dp" },
        { TextView, text = "project by Learning With Gulab", textSize = "14sp", textColor = "#607D8B", gravity = "center", layout_width = "fill", layout_marginBottom = "25dp" },
        
        -- کوئز والا بٹن
        { Button, id = "btn_qa", text = "Dilchasp Malomaat (Sawalan Jawaban)", layout_width = "fill", layout_marginTop = "5dp", padding = "15dp", backgroundColor = "#009688", textColor = "#FFFFFF" },
        
        -- نیا عجائب القرآن والا بٹن (رومن میں)
        { Button, id = "btn_ajaib", text = "Ajaib ul Quran", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#FF9800", textColor = "#FFFFFF", padding = "15dp" },
        
        -- ایگزٹ بٹن
        { Button, id = "btn_exit", text = "Exit", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#F44336", textColor = "#FFFFFF", padding = "15dp" }
    }

    dlg.setView(loadlayout(main_layout, layout_views))
    dlg.setCancelable(false)
    layout_views.tv_title.setTypeface(Typeface.DEFAULT_BOLD)

    layout_views.btn_qa.onClick = function()
        showQASubMenu()
    end
    
    -- نئے بٹن کا کلک ایونٹ
    layout_views.btn_ajaib.onClick = function()
        openAjaibQuran()
    end

    layout_views.btn_exit.onClick = function()
        dlg.dismiss() 
    end

    dlg.show()
end

showQuizMainDialog()