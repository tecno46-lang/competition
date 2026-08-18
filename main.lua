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

-- آپ کے گٹ ہب فولڈر کا ڈائریکٹ پاتھ
local BASE_URL = "https://raw.githubusercontent.com/tecno46-lang/competition/main/question%20answer%20data/"

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

-- کسٹم وائس سرچ کا فنکشن (صرف Toast نوٹیفکیشن کے ساتھ)
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

-- سوال اور جواب دکھانے والا ڈائیلاگ
local function showQuestionDetailsDialog(itemTitle, itemDetails)
    itemTitle = itemTitle:gsub("%[.-%]", ""):gsub("%(start_span%)", ""):gsub("%(end_span%)", "")
    itemDetails = itemDetails:gsub("%[.-%]", ""):gsub("%(start_span%)", ""):gsub("%(end_span%)", "")

    local detail_dlg = LuaDialog(activity)
    local detail_views = {}
    local detail_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_q_title", text = itemTitle, textSize = "20sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "15dp" },
        { ScrollView, layout_width = "fill", layout_weight = 1, { TextView, text = itemDetails, textSize = "18sp", textColor = "#333333", layout_width = "fill", paddingBottom = "10dp" } },
        { Button, id = "btn_close", text = "Close", layout_width = "fill", layout_marginTop = "15dp", backgroundColor = "#9E9E9E", textColor = "#FFFFFF", padding = "15dp" }
    }

    detail_dlg.setView(loadlayout(detail_layout, detail_views))
    detail_dlg.setCancelable(false)
    detail_views.tv_q_title.setTypeface(Typeface.DEFAULT_BOLD)

    detail_views.btn_close.onClick = function() detail_dlg.dismiss() end
    
    detail_dlg.show()
end

local function showQuestionsListDialog(data, titleText)
    local list_dlg = LuaDialog(activity)
    list_dlg.setTitle(titleText)
    
    local list_views = {}
    local list_layout = {
        LinearLayout, orientation = "vertical", padding = "15dp", layout_width = "fill", layout_height = "fill",
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "5dp", gravity = "center_vertical",
            { EditText, id = "et_search", hint = "Search question...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_voice", text = "Voice Search 🎤", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        -- کل سوالات کی تعداد دکھانے کے لیے ٹیکسٹ ویو
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
                local cleanTitle = title:gsub("%[.-%]", ""):gsub("%(start_span%)", ""):gsub("%(end_span%)", "")
                
                cleanTitle = cleanTitle:gsub("سوال نمبر %d+[%:۔%-]?%s*", "")
                cleanTitle = tostring(count) .. "۔ " .. cleanTitle

                btn.setText(cleanTitle)
                btn.setTextSize(16)
                btn.setPadding(20, 20, 20, 20)
                
                local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                params.setMargins(0, 0, 0, 10)
                btn.setLayoutParams(params)
                
                btn.setOnClickListener(function()
                    showQuestionDetailsDialog(cleanTitle, details)
                end)
                
                list_views.questions_container.addView(btn)
            end
        end
        -- ٹوٹل گنتی کو اپڈیٹ کرنا
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
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_marginBottom = "5dp", gravity = "center_vertical",
            { EditText, id = "et_cat_search", hint = "Search category...", layout_width = "0dp", layout_weight = 1, singleLine = true },
            { Button, id = "btn_cat_voice", text = "Voice Search 🎤", textSize = "14sp", padding = "5dp", textColor = "#FFFFFF", backgroundColor = "#2196F3" }
        },
        -- کل کیٹیگریز کی تعداد دکھانے کے لیے ٹیکسٹ ویو
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
    
    -- اردو اور رومن اردو دونوں ناموں کے ساتھ 91 کیٹیگریز کی لسٹ
    local qa_categories = {
        {file="allah_taala.json", name="اللہ تعالیٰ", roman="Allah Ta'ala"},
        {file="nabuwat.json", name="نبوت ورسالت", roman="Nabuwat o Risalat"},
        {file="farishtay.json", name="فرشتے", roman="Farishtay"},
        {file="jinnat.json", name="جنات", roman="Jinnat"},
        {file="jannat.json", name="جنت", roman="Jannat"},
        {file="dozakh.json", name="دوزخ", roman="Dozakh"},
        {file="barzakh.json", name="عالم برزخ", roman="Aalam-e-Barzakh"},
        {file="qayamat_nishaniyan.json", name="قیامت کی نشانیاں", roman="Qayamat Ki Nishaniyan"},
        {file="qayamat.json", name="قیامت", roman="Qayamat"},
        {file="iman_kufr.json", name="ایمان وکفر", roman="Iman o Kufr"},
        {file="wilayat.json", name="ولایت", roman="Wilayat"},
        {file="taharat.json", name="طہارت", roman="Taharat"},
        {file="wuzu.json", name="وضو", roman="Wuzu"},
        {file="ghusl.json", name="غسل", roman="Ghusl"},
        {file="tayammum.json", name="تیمم", roman="Tayammum"},
        {file="azan.json", name="اذان واقامت", roman="Azan o Iqamat"},
        {file="namaz.json", name="نماز", roman="Namaz"},
        {file="namaz_sharait.json", name="نماز کی شرائط", roman="Namaz Ki Sharait"},
        {file="namaz_faraiz.json", name="نماز کے فرائض", roman="Namaz Ke Faraiz"},
        {file="sajda_saho.json", name="واجبات نماز اور سجدہ سہو", roman="Wajibat-e-Namaz aur Sajda Saho"},
        {file="namaz_witr.json", name="نماز وتر", roman="Namaz-e-Witr"},
        {file="sunnat_nawafil.json", name="سنتیں اور نوافل", roman="Sunnatain aur Nawafil"},
        {file="taraweeh.json", name="تراویح", roman="Taraweeh"},
        {file="qaza_namaz.json", name="قضا نمازیں", roman="Qaza Namazain"},
        {file="sajda_tilawat.json", name="سجدہ تلاوت", roman="Sajda Tilawat"},
        {file="musafir_namaz.json", name="مسافر کی نماز", roman="Musafir Ki Namaz"},
        {file="jumma.json", name="جمعہ", roman="Jumma"},
        {file="eidein.json", name="عیدین", roman="Eidein"},
        {file="mayyit_ghusl.json", name="میت کا غسل اور کفن", roman="Mayyit Ka Ghusl aur Kafan"},
        {file="namaz_janaza.json", name="نماز جنازہ", roman="Namaz-e-Janaza"},
        {file="qabr_dafan.json", name="قبر و دفن", roman="Qabr o Dafan"},
        {file="zakat.json", name="زکوٰۃ", roman="Zakat"},
        {file="sadqa.json", name="صدقہ", roman="Sadqa"},
        {file="roza.json", name="روزہ", roman="Roza"},
        {file="hajj_umrah.json", name="حج وعمرہ", roman="Hajj o Umrah"},
        {file="qurbani.json", name="ذِبح اور قربانی", roman="Zibh aur Qurbani"},
        {file="nikah.json", name="نکاح", roman="Nikah"},
        {file="talaq.json", name="طلاق، عدت اور سوگ", roman="Talaq, Iddat aur Sog"},
        {file="qasam.json", name="قسم", roman="Qasam"},
        {file="luqata.json", name="لُقَطہ", roman="Luqata"},
        {file="waqf.json", name="وقف اور چندہ", roman="Waqf aur Chanda"},
        {file="masjid.json", name="مسجد", roman="Masjid"},
        {file="tijarat.json", name="کَسْب اور تجارت", roman="Kasb aur Tijarat"},
        {file="qarz_sood.json", name="قرض اور سود", roman="Qarz aur Sood"},
        {file="khana.json", name="کھانا", roman="Khana"},
        {file="dawat.json", name="دعوت اور مہمان نوازی", roman="Dawat aur Mehman Nawazi"},
        {file="libas.json", name="لباس، انگوٹھی اور زیور", roman="Libas, Angoothi aur Zewar"},
        {file="zeenat.json", name="زینت", roman="Zeenat"},
        {file="aadab.json", name="بیٹھنے سونے اور چلنے کے آداب", roman="Baithne, Sonay aur Chalne Ke Aadab"},
        {file="salam.json", name="سلام اور مُصافَحَہ", roman="Salam aur Musafaha"},
        {file="cheenk.json", name="چھینک اور جماہی", roman="Cheenk aur Jamahi"},
        {file="ziyarat.json", name="زیارتِ قبور", roman="Ziyarat-e-Quboor"},
        {file="quran_fazail.json", name="قرآن کریم (فضائل و معلومات)", roman="Quran Kareem (Fazail o Maloomat)"},
        {file="quran_ayaat.json", name="آیات اور سورتوں کی معلومات", roman="Ayaat aur Surton Ki Maloomat"},
        {file="anbiya.json", name="انبیائے کرام", roman="Anbiya-e-Kiram"},
        {file="husn_akhlaq.json", name="حُسْنِ اخلاق", roman="Husn-e-Akhlaq"},
        {file="khauf_e_khuda.json", name="خوفِ خدا", roman="Khauf-e-Khuda"},
        {file="silah_rahmi.json", name="صلۂ رحمی", roman="Silah Rahmi"},
        {file="sabr_shukr.json", name="صبر و شکر", roman="Sabr o Shukr"},
        {file="tauba.json", name="توبہ و اِسْتِغفار", roman="Tauba o Istighfar"},
        {file="ilm.json", name="علم کے فضائل", roman="Ilm Ke Fazail"},
        {file="walidein.json", name="والدین اور ان کے حقوق", roman="Walidein aur un ke Huqooq"},
        {file="aulad.json", name="اولاد اور ان کے حقوق", roman="Aulad aur un ke Huqooq"},
        {file="gheebat.json", name="غیبت", roman="Gheebat"},
        {file="badshuguni.json", name="بدشگونی", roman="Badshuguni"},
        {file="badgumani.json", name="بدگمانی", roman="Badgumani"},
        {file="hirs.json", name="حرص", roman="Hirs"},
        {file="jhoot.json", name="جھوٹ", roman="Jhoot"},
        {file="bughz_keena.json", name="بغض و کینہ", roman="Bughz o Keena"},
        {file="hasad.json", name="حسد", roman="Hasad"},
        {file="ghussa.json", name="غصہ", roman="Ghussa"},
        {file="takabbur.json", name="تکبر", roman="Takabbur"},
        {file="riyakari.json", name="ریاکاری", roman="Riyakari"},
        {file="seerat_un_nabi.json", name="سیرت", roman="Seerat"},
        {file="siddique_akbar.json", name="سیدنا صدیق اکبر", roman="Syedna Siddique Akbar"},
        {file="umar_farooq.json", name="سیدنا عمر فاروق اعظم", roman="Syedna Umar Farooq Azam"},
        {file="usman_ghani.json", name="سیدنا عثمان غنی", roman="Syedna Usman Ghani"},
        {file="ali_murtaza.json", name="سیدنا علی المرتضیٰ", roman="Syedna Ali Al-Murtaza"},
        {file="ashra_mubashara.json", name="عَشَرَۂ مُبَشَّرَہ", roman="Ashra Mubashara"},
        {file="sahaba_kiram.json", name="صحابہ کرام", roman="Sahaba Kiram"},
        {file="ummahat_ul_momineen.json", name="امہات المومنین", roman="Ummahat ul Momineen"},
        {file="ahl_e_bait.json", name="اہلِ بیت", roman="Ahl-e-Bait"},
        {file="ulama_mujtahideen.json", name="علما و مُجْتہدین", roman="Ulama o Mujtahideen"},
        {file="auliya_saliheen.json", name="اولیاء و صالحین", roman="Auliya o Saliheen"},
        {file="ala_hazrat.json", name="امامِ اہلسنت اعلیٰ حضرت", roman="Imam-e-Ahlesunnat Ala Hazrat"},
        {file="ameer_e_ahlesunnat.json", name="امیرِ اہلسنّت", roman="Ameer-e-Ahlesunnat"},
        {file="zikr_o_azkar.json", name="ذکر و اذکار", roman="Zikr o Azkar"},
        {file="darood_pak.json", name="درود پاک", roman="Darood Pak"},
        {file="baiyat_o_tareeqat.json", name="بیعت و طریقت", roman="Baiyat o Tareeqat"},
        {file="muqaddas_maqamat.json", name="مُقَدَّس مقامات", roman="Muqaddas Maqamat"},
        {file="dawat_e_islami.json", name="دعوت اسلامی کا تعارف", roman="Dawat-e-Islami Ka Taaruf"}
    }
    
    local function populateCatList(query)
        cat_views.cat_container.removeAllViews()
        local count = 0
        local qStr = query:lower()

        for i, item in ipairs(qa_categories) do
            -- اردو اور رومن اردو کو ملا کر نام بنانا
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
                
                btn.setOnClickListener(function()
                    fetchCategoryData(item.file, item.name .. " (" .. item.roman .. ")")
                end)
                
                cat_views.cat_container.addView(btn)
            end
        end
        -- ٹوٹل کیٹیگریز گنتی اپڈیٹ کرنا
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

function showQuizMainDialog()
    local dlg = LuaDialog(activity)
    
    local layout_views = {}
    local main_layout = {
        LinearLayout, orientation = "vertical", padding = "20dp", layout_width = "fill", layout_height = "wrap",
        { TextView, id = "tv_title", text = "Sawalat Aur Jawabat Ki Duniya", textSize = "24sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_marginBottom = "5dp" },
        { TextView, text = "project by learning with Gulab", textSize = "14sp", textColor = "#607D8B", gravity = "center", layout_width = "fill", layout_marginBottom = "25dp" },
        { Button, id = "btn_qa", text = "Sawalat Aur Jawabat", layout_width = "fill", layout_marginTop = "5dp", padding = "15dp", backgroundColor = "#009688", textColor = "#FFFFFF" },
        -- نعتیہ کلام کا بٹن ختم کر دیا گیا ہے
        { Button, id = "btn_exit", text = "Exit", layout_width = "fill", layout_marginTop = "10dp", backgroundColor = "#F44336", textColor = "#FFFFFF", padding = "15dp" }
    }

    dlg.setView(loadlayout(main_layout, layout_views))
    dlg.setCancelable(false)
    layout_views.tv_title.setTypeface(Typeface.DEFAULT_BOLD)

    layout_views.btn_qa.onClick = function()
        showQASubMenu()
    end

    layout_views.btn_exit.onClick = function()
        dlg.dismiss() 
    end

    dlg.show()
end

showQuizMainDialog()