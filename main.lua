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
import "android.speech.tts.TextToSpeech"
import "java.util.Locale"
import "java.lang.String"
import "android.widget.ArrayAdapter"
import "android.widget.AdapterView"
import "android.text.TextWatcher"

local activity = this

-- آپ کے گٹ ہب فولڈر کا ڈائریکٹ پاتھ
local BASE_URL = "https://raw.githubusercontent.com/tecno46-lang/competition/main/question%20answer%20data/"

local tts
local engineList = {}    
local engineLabels = {}  
local currentEnginePkg = nil 

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

-- کسٹم وائس سرچ کا فنکشن (جو ڈائریکٹ ایڈٹ باکس میں لکھے گا)
local function startVoiceSearch(targetEditText)
    local recordIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    recordIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    recordIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ur-PK")

    local speechRecord = SpeechRecognizer.createSpeechRecognizer(activity)
    speechRecord.setRecognitionListener(RecognitionListener{
        onReadyForSpeech = function() 
            if tts ~= nil then tts.speak("جی، فرمائیے", TextToSpeech.QUEUE_FLUSH, nil) end
        end,
        onResults = function(results)
            local data = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if data and data.size() > 0 then
                local spokenText = data.get(0)
                spokenText = fixSpokenText(spokenText)
                if targetEditText ~= nil then
                    targetEditText.setText(spokenText)
                end
                if tts ~= nil then tts.speak("لکھ دیا گیا ہے", TextToSpeech.QUEUE_FLUSH, nil) end
            end
            speechRecord.destroy()
        end,
        onError = function()
            if tts ~= nil then tts.speak("معذرت، سمجھ نہیں سکا", TextToSpeech.QUEUE_FLUSH, nil) end
            speechRecord.destroy()
        end
    })

    speechRecord.startListening(recordIntent)
end

local function initTTS(enginePackage)
    if tts ~= nil then tts.shutdown() end
    
    if enginePackage == nil then
        tts = TextToSpeech(activity, TextToSpeech.OnInitListener{
            onInit = function(status)
                if status == TextToSpeech.SUCCESS then
                    tts.setLanguage(Locale("ur", "PK"))
                    if #engineList == 0 then
                        local engines = tts.getEngines()
                        for i = 0, engines.size() - 1 do
                            local eng = engines.get(i)
                            table.insert(engineList, eng.name)
                            table.insert(engineLabels, eng.label)
                        end
                    end
                end
            end
        })
    else
        tts = TextToSpeech(activity, TextToSpeech.OnInitListener{
            onInit = function(status)
                if status == TextToSpeech.SUCCESS then
                    tts.setLanguage(Locale("ur", "PK"))
                end
            end
        }, enginePackage)
    end
end

initTTS(nil)

local function showSettingsDialog()
    local set_dlg = LuaDialog(activity)
    local set_views = {}
    
    if #engineList == 0 then
        Toast.makeText(activity, "Engines are loading, please try again shortly.", Toast.LENGTH_SHORT).show()
        return
    end

    local set_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, text = "Select TTS Engine", textSize = "20sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "15dp" },
        { Spinner, id = "spinner_tts", layout_width = "fill", layout_marginBottom = "15dp" },
        { Button, id = "btn_save_settings", text = "Save", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#4CAF50", textColor = "#FFFFFF", padding = "10dp" }
    }
    
    set_dlg.setView(loadlayout(set_layout, set_views))
    
    local adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, String(engineLabels))
    adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    set_views.spinner_tts.setAdapter(adapter)
    
    local tempSelectedPkg = currentEnginePkg
    set_views.spinner_tts.setOnItemSelectedListener(AdapterView.OnItemSelectedListener{
        onItemSelected = function(parent, view, position, id) tempSelectedPkg = engineList[position + 1] end,
        onNothingSelected = function(parent) end
    })
    
    set_views.btn_save_settings.onClick = function()
        if tempSelectedPkg ~= nil and tempSelectedPkg ~= currentEnginePkg then
            currentEnginePkg = tempSelectedPkg
            initTTS(currentEnginePkg) 
            Toast.makeText(activity, "TTS Engine changed successfully", Toast.LENGTH_SHORT).show()
        else
            Toast.makeText(activity, "No changes made", Toast.LENGTH_SHORT).show()
        end
        set_dlg.dismiss()
    end
    
    set_dlg.show()
end

local function showQuestionDetailsDialog(itemTitle, itemDetails)
    itemTitle = itemTitle:gsub("%[.-%]", ""):gsub("%(start_span%)", ""):gsub("%(end_span%)", "")
    itemDetails = itemDetails:gsub("%[.-%]", ""):gsub("%(start_span%)", ""):gsub("%(end_span%)", "")

    local detail_dlg = LuaDialog(activity)
    local detail_views = {}
    local detail_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_q_title", text = itemTitle, textSize = "20sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "15dp" },
        { ScrollView, layout_width = "fill", layout_weight = 1, { TextView, text = itemDetails, textSize = "18sp", textColor = "#333333", layout_width = "fill", paddingBottom = "10dp" } },
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginTop = "15dp",
            { Button, id = "btn_listen", text = "Listen", layout_width = "0dp", layout_weight = 1, layout_marginRight = "5dp", backgroundColor = "#9C27B0", textColor = "#FFFFFF" },
            { Button, id = "btn_stop", text = "Stop", layout_width = "0dp", layout_weight = 1, layout_marginLeft = "2dp", layout_marginRight = "2dp", backgroundColor = "#F44336", textColor = "#FFFFFF" },
            { Button, id = "btn_close", text = "Close", layout_width = "0dp", layout_weight = 1, layout_marginLeft = "5dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF" }
        }
    }

    detail_dlg.setView(loadlayout(detail_layout, detail_views))
    detail_dlg.setCancelable(false)
    detail_views.tv_q_title.setTypeface(Typeface.DEFAULT_BOLD)

    detail_views.btn_listen.onClick = function()
        if tts ~= nil then 
            local speechText = itemTitle .. "۔ جواب: " .. itemDetails
            tts.speak(speechText, TextToSpeech.QUEUE_FLUSH, nil) 
        end
    end
    detail_views.btn_stop.onClick = function() if tts ~= nil then tts.stop() end end
    detail_views.btn_close.onClick = function() detail_dlg.dismiss() end
    
    detail_dlg.show()
end

local function showQuestionsListDialog(data, titleText)
    local list_dlg = LuaDialog(activity)
    list_dlg.setTitle(titleText)
    
    local list_views = {}
    local list_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "10dp", gravity = "center_vertical",
            { EditText, id = "et_search", hint = "سوال تلاش کریں...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_voice", text = "وائس سرچ 🎤", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1, 
            { LinearLayout, id = "questions_container", orientation = "vertical", layout_width = "fill" } 
        },
        { Button, id = "btn_close_list", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    
    list_dlg.setView(loadlayout(list_layout, list_views))

    -- وائس سرچ بٹن
    list_views.btn_voice.onClick = function()
        startVoiceSearch(list_views.et_search)
    end

    local items = data.qa_list or data

    local function populateList(query)
        list_views.questions_container.removeAllViews()
        
        for i, item in ipairs(items) do
            local title = item.question or item.title or ""
            local details = item.answer or item.details or ""
            
            if query == "" or string.find(title, query, 1, true) then
                local btn = Button(activity)
                local cleanTitle = title:gsub("%[.-%]", ""):gsub("%(start_span%)", ""):gsub("%(end_span%)", "")
                btn.setText(cleanTitle)
                btn.setTextSize(16)
                btn.setPadding(20, 20, 20, 20)
                
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 10)
                btn.setLayoutParams(params)
                
                btn.setOnClickListener(function()
                    showQuestionDetailsDialog(title, details)
                end)
                
                list_views.questions_container.addView(btn)
            end
        end
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

local function fetchCategoryData(filename, categoryName)
    Toast.makeText(activity, "Please wait...", Toast.LENGTH_SHORT).show()
    
    local url = BASE_URL .. filename .. "?t=" .. tostring(os.time())
    
    Http.get(url, function(code, response)
        if code == 200 and response and response:match("%S") then
            local cjson = require "cjson"
            local success, data = pcall(cjson.decode, response)
            if success and data then
                showQuestionsListDialog(data, categoryName)
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
    local cat_dlg = LuaDialog(activity)
    cat_dlg.setTitle("کیٹیگری منتخب کریں")
    
    local cat_views = {}
    local cat_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        -- کیٹیگری میں بھی سرچ اور وائس سرچ شامل کیا گیا ہے
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "10dp", gravity = "center_vertical",
            { EditText, id = "et_cat_search", hint = "کیٹیگری تلاش کریں...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_cat_voice", text = "وائس سرچ 🎤", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        { ScrollView, layout_width = "fill", layout_height = "0dp", layout_weight = 1, 
            { LinearLayout, id = "cat_container", orientation = "vertical", layout_width = "fill" } 
        },
        { Button, id = "btn_close_cat", text = "Back", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }
    
    cat_dlg.setView(loadlayout(cat_layout, cat_views))
    
    -- کیٹیگری کے وائس سرچ بٹن کا فنکشن
    cat_views.btn_cat_voice.onClick = function()
        startVoiceSearch(cat_views.et_cat_search)
    end
    
    local qa_categories = {
        {file="allah_taala.json", name="اللہ تعالیٰ"},
        {file="nabuwat.json", name="نبوت ورسالت"},
        {file="farishtay.json", name="فرشتے"},
        {file="jinnat.json", name="جنات"},
        {file="jannat.json", name="جنت"},
        {file="dozakh.json", name="دوزخ"},
        {file="barzakh.json", name="عالم برزخ"},
        {file="qayamat_nishaniyan.json", name="قیامت کی نشانیاں"},
        {file="qayamat.json", name="قیامت"},
        {file="iman_kufr.json", name="ایمان وکفر"},
        {file="wilayat.json", name="ولایت"},
        {file="taharat.json", name="طہارت"},
        {file="wuzu.json", name="وضو"},
        {file="ghusl.json", name="غسل"},
        {file="tayammum.json", name="تیمم"},
        {file="azan.json", name="اذان واقامت"},
        {file="namaz.json", name="نماز"},
        {file="namaz_sharait.json", name="نماز کی شرائط"},
        {file="namaz_faraiz.json", name="نماز کے فرائض"},
        {file="sajda_saho.json", name="واجبات نماز اور سجدہ سہو"},
        {file="namaz_witr.json", name="نماز وتر"},
        {file="sunnat_nawafil.json", name="سنتیں اور نوافل"},
        {file="taraweeh.json", name="تراویح"},
        {file="qaza_namaz.json", name="قضا نمازیں"},
        {file="sajda_tilawat.json", name="سجدہ تلاوت"},
        {file="musafir_namaz.json", name="مسافر کی نماز"},
        {file="jumma.json", name="جمعہ"},
        {file="eidein.json", name="عیدین"},
        {file="mayyit_ghusl.json", name="میت کا غسل اور کفن"},
        {file="namaz_janaza.json", name="نماز جنازہ"},
        {file="qabr_dafan.json", name="قبر و دفن"},
        {file="zakat.json", name="زکوٰۃ"},
        {file="sadqa.json", name="صدقہ"},
        {file="roza.json", name="روزہ"},
        {file="hajj_umrah.json", name="حج وعمرہ"},
        {file="qurbani.json", name="ذِبح اور قربانی"},
        {file="nikah.json", name="نکاح"},
        {file="talaq.json", name="طلاق، عدت اور سوگ"},
        {file="qasam.json", name="قسم"},
        {file="luqata.json", name="لُقَطہ"},
        {file="waqf.json", name="وقف اور چندہ"},
        {file="masjid.json", name="مسجد"},
        {file="tijarat.json", name="کَسْب اور تجارت"},
        {file="qarz_sood.json", name="قرض اور سود"},
        {file="khana.json", name="کھانا"},
        {file="dawat.json", name="دعوت اور مہمان نوازی"},
        {file="libas.json", name="لباس، انگوٹھی اور زیور"},
        {file="zeenat.json", name="زینت"},
        {file="aadab.json", name="بیٹھنے سونے اور چلنے کے آداب"},
        {file="salam.json", name="سلام اور مُصافَحَہ"},
        {file="cheenk.json", name="چھینک اور جماہی"},
        {file="ziyarat.json", name="زیارتِ قبور"},
        {file="quran_fazail.json", name="قرآن کریم (فضائل و معلومات)"},
        {file="quran_ayaat.json", name="آیات اور سورتوں کی معلومات"},
        {file="anbiya.json", name="انبیائے کرام"},
        {file="husn_akhlaq.json", name="حُسْنِ اخلاق"},
        {file="khauf_e_khuda.json", name="خوفِ خدا"},
        {file="silah_rahmi.json", name="صلۂ رحمی"},
        {file="sabr_shukr.json", name="صبر و شکر"},
        {file="tauba.json", name="توبہ و اِسْتِغفار"},
        {file="ilm.json", name="علم کے فضائل"},
        {file="walidein.json", name="والدین اور ان کے حقوق"},
        {file="aulad.json", name="اولاد اور ان کے حقوق"},
        {file="gheebat.json", name="غیبت"},
        {file="badshuguni.json", name="بدشگونی"},
        {file="badgumani.json", name="بدگمانی"},
        {file="hirs.json", name="حرص"},
        {file="jhoot.json", name="جھوٹ"},
        {file="bughz_keena.json", name="بغض و کینہ"},
        {file="hasad.json", name="حسد"},
        {file="ghussa.json", name="غصہ"},
        {file="takabbur.json", name="تکبر"},
        {file="riyakari.json", name="ریاکاری"},
        {file="seerat_un_nabi.json", name="سیرت"},
        {file="siddique_akbar.json", name="سیدنا صدیق اکبر"},
        {file="umar_farooq.json", name="سیدنا عمر فاروق اعظم"},
        {file="usman_ghani.json", name="سیدنا عثمان غنی"},
        {file="ali_murtaza.json", name="سیدنا علی المرتضیٰ"},
        {file="ashra_mubashara.json", name="عَشَرَۂ مُبَشَّرَہ"},
        {file="sahaba_kiram.json", name="صحابہ کرام"},
        {file="ummahat_ul_momineen.json", name="امہات المومنین"},
        {file="ahl_e_bait.json", name="اہلِ بیت"},
        {file="ulama_mujtahideen.json", name="علما و مُجْتہدین"},
        {file="auliya_saliheen.json", name="اولیاء و صالحین"},
        {file="ala_hazrat.json", name="امامِ اہلسنت اعلیٰ حضرت"},
        {file="ameer_e_ahlesunnat.json", name="امیرِ اہلسنّت"},
        {file="zikr_o_azkar.json", name="ذکر و اذکار"},
        {file="darood_pak.json", name="درود پاک"},
        {file="baiyat_o_tareeqat.json", name="بیعت و طریقت"},
        {file="muqaddas_maqamat.json", name="مُقَدَّس مقامات"},
        {file="dawat_e_islami.json", name="دعوت اسلامی کا تعارف"}
    }
    
    local function populateCatList(query)
        cat_views.cat_container.removeAllViews()
        for i, item in ipairs(qa_categories) do
            local catName = tostring(i) .. "۔ " .. item.name
            if query == "" or string.find(catName, query, 1, true) then
                local btn = Button(activity)
                btn.setText(catName)
                btn.setTextSize(16)
                btn.setPadding(20, 20, 20, 20)
                
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 10)
                btn.setLayoutParams(params)
                
                btn.setOnClickListener(function()
                    fetchCategoryData(item.file, item.name)
                end)
                
                cat_views.cat_container.addView(btn)
            end
        end
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

function showQuizMainDialog()
    local dlg = LuaDialog(activity)
    
    local layout_views = {}
    local main_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_title", text = "خزانہ علم", textSize = "24sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "25dp" },
        { Button, id = "btn_qa", text = "سوالات اور جوابات", layout_width = "fill", layout_marginTop = "5dp", padding = "15dp", backgroundColor = "#009688", textColor = "#FFFFFF" },
        { Button, id = "btn_settings", text = "Settings", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#FF9800", textColor = "#FFFFFF", padding = "15dp" },
        { Button, id = "btn_exit", text = "Exit", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#F44336", textColor = "#FFFFFF", padding = "15dp" }
    }

    dlg.setView(loadlayout(main_layout, layout_views))
    dlg.setCancelable(false)
    layout_views.tv_title.setTypeface(Typeface.DEFAULT_BOLD)

    layout_views.btn_qa.onClick = function()
        showQASubMenu()
    end
    
    layout_views.btn_settings.onClick = function() showSettingsDialog() end

    layout_views.btn_exit.onClick = function()
        if tts ~= nil then tts.stop(); tts.shutdown() end
        dlg.dismiss() 
    end

    dlg.show()
end

showQuizMainDialog()