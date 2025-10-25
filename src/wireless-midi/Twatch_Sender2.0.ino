// now runing on esp32 core 3.3.1
// added info channel to support multiple watches

#include <LilyGoLib.h>
#include <LV_Helper.h>
#include <WiFi.h>
#include <esp_now.h>
#include <Preferences.h>

Preferences pref;

// Setup
uint8_t receiverAddress[] = {0xD8, 0x3B, 0xDA, 0x46, 0xE0, 0x54};  // ws E8:06:90:95:86:A8 // naked seeed {0xD8, 0x3B, 0xDA, 0x41, 0x68, 0xB0}  // Receiver MAC address  D8:3B:DA:46:E0:54
esp_now_peer_info_t peerInfo;

typedef struct struct_message {
  uint8_t midi;
  uint8_t info;
  uint8_t midi2;
  uint8_t info2;
} struct_message;

struct_message myData;


lv_obj_t *Zball1;
lv_obj_t *Zball2;
lv_obj_t *Zball3;
lv_obj_t *Zball4;
lv_obj_t *Zball5;
lv_obj_t *Zball6;
lv_obj_t *btnToggleBall;
lv_obj_t *pairLabel;
lv_obj_t *sensBtn;
lv_obj_t *sensLabel;
lv_obj_t *maxMIDIbtn;
lv_obj_t *maxMIDI;
lv_obj_t *minMIDIbtn;
lv_obj_t *minMIDI;
lv_obj_t *CCbtn;
lv_obj_t *CClabel;
lv_obj_t *xyzBtn;
lv_obj_t *xyzLabel;
lv_obj_t *joltBtn;
lv_obj_t *joltLabel;
lv_obj_t *slider;
lv_obj_t *btnLeft;
lv_obj_t *leftIcon;
lv_obj_t *btnRight;
lv_obj_t *rightIcon;
static lv_style_t style_btn_gradient;
static lv_style_t style_large_text;
static lv_style_t style_medium_text;

uint32_t red1 = 0x420000;  //dark red
uint32_t red2 = 0x750000;
uint32_t red3 = 0x8c0c0c;
uint32_t red4 = 0xb40e0e;
uint32_t red5 = 0xd50e0e;
uint32_t red6 = 0xE50000;  //red

uint32_t blue1 = 0x003c3c; //dark blue
uint32_t blue2 = 0x006969;
uint32_t blue3 = 0x009696;
uint32_t blue4 = 0x00c8c8;
uint32_t blue5 = 0x00e1e1;
uint32_t blue6 = 0x00ffff; //blue

uint32_t purple1 = 0x300047; //dark purp
uint32_t purple2 = 0x470069;
uint32_t purple3 = 0x5a0085;
uint32_t purple4 = 0x7600ad;
uint32_t purple5 = 0x8d00cf;
uint32_t purple6 = 0xae00ff; //purp

uint32_t color1 = red1;
uint32_t color2 = red2;
uint32_t color3 = red3;
uint32_t color4 = red4;
uint32_t color5 = red5;
uint32_t color6 = red6;

uint32_t grey1 = 0x232a38;  // icons background
uint32_t selectedColor = red6;  //red
uint32_t backgroundColor = red1;


unsigned long disconnectionTime = 0;
bool wasConnected = false;
bool disconnected = false;
bool sta = false;
uint32_t lastMillis;
int16_t latency;
int8_t preset = 1;
int8_t sliderValue = 63;
int8_t btnSelect = 0;
int8_t xyz = 3;
int16_t data;
int8_t CC = 74;  // synth cutoff
int8_t maxMIDIvalue = 127;     
int8_t minMIDIvalue = 0;
int8_t sensitivity = 100;
int16_t prev_xyz, prev_CC, prev_max, prev_min, prev_sens;
int8_t buzz1 = 48;
int8_t buzz2 = 47;
int16_t x, y, z;
int16_t Zball1map, Zball2map, Zball3map, Zball4map, Zball5map, Zball6map;
int16_t mapX1, mapX2, mapX3, mapX4, mapX5, mapX6;
int16_t mapY1, mapY2, mapY3, mapY4, mapY5, mapY6;
bool starting = true;
bool toggleBall = false;
bool jolt = true;
bool prev_jolt;
bool lastSend = false;
bool inSettings = false;
float smoothedX = 0;
float smoothedY = 0;
float smoothedZ = 0;

float alpha = 0.1;  // smooting algorythim

unsigned long lastXJoltTime = 0; 
int16_t joltThreshold = 1000; // Sensitivity threshold for detecting jolts 
int16_t joltCooldown = 500;  // Prevent jolt toggle spam

void detectXJolt() {   // could try switching to raw x data and increase threshhold
    if (jolt && !inSettings) {
        unsigned long currentTime = millis();

        if ((abs(x) > joltThreshold || abs(y) > joltThreshold) && toggleBall == true) {
            if (currentTime - lastXJoltTime > joltCooldown) {
              showBalls();
              lastXJoltTime = currentTime;
            }
        } else if (x < -joltThreshold && toggleBall == false) {    // Check for a jolt in the positive X direction
            if (currentTime - lastXJoltTime > joltCooldown) {
                //myData.midi = minMIDIvalue;
                //lv_slider_set_value(slider, minMIDIvalue, LV_ANIM_OFF);
                hideBalls();
                lastXJoltTime = currentTime; // Update the last jolt time
            }
        }
        else if (x > joltThreshold && toggleBall == false) {
            if (currentTime - lastXJoltTime > joltCooldown) {
                //myData.midi = maxMIDIvalue; 
                //lv_slider_set_value(slider, maxMIDIvalue, LV_ANIM_OFF);
                hideBalls();
                lastXJoltTime = currentTime; // Update the last jolt time
            }
        }
    }
}

void swipe_event_handler(lv_event_t * e) {
    lv_obj_t * screen = lv_event_get_target_obj(e);
    lv_dir_t dir = lv_indev_get_gesture_dir(lv_indev_get_act());

    if (!inSettings) {
        savePresetIfChanged();
        switch(dir) {
            case LV_DIR_LEFT:
                preset = preset % 3 + 1;  // Cycles 1->2->3->1
                break;
            case LV_DIR_RIGHT:
                preset = (preset + 1) % 3 + 1;  // Cycles 1->3->2->1
                break;
            case LV_DIR_TOP:
                //printf("Swiped up!\n");
                break;
            case LV_DIR_BOTTOM:
                //printf("Swiped down!\n");
                break;
            default:
                break;
        }
        if (preset == 1) {
            color1 = red1;
            color2 = red2;
            color3 = red3;
            color4 = red4;
            color5 = red5;
            color6 = red6;
        } else if (preset == 2) {
            color1 = blue1;
            color2 = blue2;
            color3 = blue3;
            color4 = blue4;
            color5 = blue5;
            color6 = blue6;             
        } else if (preset == 3) {
            color1 = purple1;
            color2 = purple2;
            color3 = purple3;
            color4 = purple4;
            color5 = purple5;
            color6 = purple6;
        }

        setupPresetValues();
        setXYZLabel();
        setJoltLabel();
        showBalls();
        //myData.midi = 127 + CC;   // update midi CC when preset changes
        //esp_err_t result = esp_now_send(receiverAddress, (uint8_t *)&myData, sizeof(myData));
    }
}

void toggleBallCallback(lv_event_t *e) {
    if (!toggleBall) {
        hideBalls();  
    } else {
        showBalls();   
    }
}

void hideBalls() {
    toggleBall = true;
    if (inSettings) {
        lv_obj_add_flag(Zball1, LV_OBJ_FLAG_HIDDEN);
        lv_obj_add_flag(Zball2, LV_OBJ_FLAG_HIDDEN);
        lv_obj_add_flag(Zball3, LV_OBJ_FLAG_HIDDEN);
        lv_obj_add_flag(Zball4, LV_OBJ_FLAG_HIDDEN);
        lv_obj_add_flag(Zball5, LV_OBJ_FLAG_HIDDEN);
        lv_obj_add_flag(Zball6, LV_OBJ_FLAG_HIDDEN);
    } else {
        lv_obj_set_style_bg_color(Zball1, lv_color_hex(0x000000), LV_PART_MAIN); // ghost balls when not in settings
        lv_obj_set_style_bg_color(Zball2, lv_color_hex(0x000000), LV_PART_MAIN); 
        lv_obj_set_style_bg_color(Zball3, lv_color_hex(0x000000), LV_PART_MAIN); 
        lv_obj_set_style_bg_color(Zball4, lv_color_hex(0x000000), LV_PART_MAIN); 
        lv_obj_set_style_bg_color(Zball5, lv_color_hex(0x000000), LV_PART_MAIN); 
        lv_obj_set_style_bg_color(Zball6, lv_color_hex(0x000000), LV_PART_MAIN); 
        lv_obj_set_style_border_width(Zball1, 2, LV_PART_MAIN);  
        lv_obj_set_style_border_width(Zball2, 2, LV_PART_MAIN);
        lv_obj_set_style_border_width(Zball3, 2, LV_PART_MAIN);
        lv_obj_set_style_border_width(Zball4, 2, LV_PART_MAIN);
        lv_obj_set_style_border_width(Zball5, 2, LV_PART_MAIN);
        lv_obj_set_style_border_width(Zball6, 2, LV_PART_MAIN);
    }
    instance.drv.stop();
    instance.drv.setWaveform(0, buzz2); 
    instance.drv.run();
}

void showBalls() {
    toggleBall = false;
    lv_obj_set_style_bg_color(Zball1, lv_color_hex(color1), LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball2, lv_color_hex(color2), LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball3, lv_color_hex(color3), LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball4, lv_color_hex(color4), LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball5, lv_color_hex(color5), LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball6, lv_color_hex(color6), LV_PART_MAIN); 
    lv_obj_clear_flag(Zball1, LV_OBJ_FLAG_HIDDEN);
    lv_obj_clear_flag(Zball2, LV_OBJ_FLAG_HIDDEN);
    lv_obj_clear_flag(Zball3, LV_OBJ_FLAG_HIDDEN);
    lv_obj_clear_flag(Zball4, LV_OBJ_FLAG_HIDDEN);
    lv_obj_clear_flag(Zball5, LV_OBJ_FLAG_HIDDEN);
    lv_obj_clear_flag(Zball6, LV_OBJ_FLAG_HIDDEN);
    lv_obj_set_style_border_width(Zball1, 0, LV_PART_MAIN);
    lv_obj_set_style_border_width(Zball2, 0, LV_PART_MAIN);
    lv_obj_set_style_border_width(Zball3, 0, LV_PART_MAIN);
    lv_obj_set_style_border_width(Zball4, 0, LV_PART_MAIN);
    lv_obj_set_style_border_width(Zball5, 0, LV_PART_MAIN);
    lv_obj_set_style_border_width(Zball6, 0, LV_PART_MAIN);
    instance.drv.stop();
    instance.drv.setWaveform(0, buzz2); 
    instance.drv.run();
}

void xyzToggler(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_CLICKED) {
        instance.drv.stop();
        instance.drv.setWaveform(0, buzz1); 
        instance.drv.run();
        xyz = (xyz % 3) + 1;
        if (xyz == 1) {
            lv_label_set_text_fmt(xyzLabel, "X");
            lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(grey1), LV_PART_MAIN); 
        } else if (xyz == 2) {
            lv_label_set_text_fmt(xyzLabel, "Y");
            lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(grey1), LV_PART_MAIN); 
        } else if (xyz == 3) {
            lv_label_set_text_fmt(xyzLabel, "Z");
            lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(selectedColor), LV_PART_MAIN); 
        }
    }
}

void joltToggler(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_CLICKED) {
        instance.drv.stop();
        instance.drv.setWaveform(0, buzz1); 
        instance.drv.run();
        if (jolt) {
            jolt = false;
            lv_obj_set_style_bg_color(joltBtn, lv_color_hex(grey1), LV_PART_MAIN);
            lv_label_set_text_fmt(joltLabel, "Jolt: \nOFF");
        } else {
            jolt = true;
            lv_obj_set_style_bg_color(joltBtn, lv_color_hex(selectedColor), LV_PART_MAIN);
            lv_label_set_text_fmt(joltLabel, "Jolt: \nON");
        } 
    }
}
void maxMIDIToggler(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_CLICKED) {
        if (btnSelect == 1) {
            untoggleBtns();
        } else {
            untoggleBtns();
            btnSelect = 1;
            sliderValue = maxMIDIvalue;
            lv_slider_set_value(slider, sliderValue, LV_ANIM_ON);
            lv_obj_set_style_bg_color(maxMIDIbtn, lv_color_hex(selectedColor), LV_PART_MAIN);
            instance.drv.stop();
            instance.drv.setWaveform(0, buzz1); 
            instance.drv.run();
        }
    }
}

void minMIDIToggler(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_CLICKED) {
        if (btnSelect == 2) {
            untoggleBtns();
        } else {
            untoggleBtns();
            btnSelect = 2;
            sliderValue = minMIDIvalue;
            lv_slider_set_value(slider, sliderValue, LV_ANIM_ON);
            lv_obj_set_style_bg_color(minMIDIbtn, lv_color_hex(selectedColor), LV_PART_MAIN);
            instance.drv.stop();
            instance.drv.setWaveform(0, buzz1); 
            instance.drv.run();
        }
    }
}

void CCToggler(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_CLICKED) {
        if (btnSelect == 3) {
            untoggleBtns();
        } else {
            untoggleBtns();
            btnSelect = 3;
            sliderValue = CC;
            lv_slider_set_value(slider, sliderValue, LV_ANIM_ON);
            lv_obj_set_style_bg_color(CCbtn, lv_color_hex(selectedColor), LV_PART_MAIN);
            instance.drv.stop();
            instance.drv.setWaveform(0, buzz1); 
            instance.drv.run();
        }
    }
}

void sensToggler(lv_event_t *e) {
    if (btnSelect == 4) {
        untoggleBtns();
    } else {
        untoggleBtns();
        btnSelect = 4;
        sliderValue = sensitivity;
        lv_slider_set_value(slider, sliderValue, LV_ANIM_ON);
        lv_obj_set_style_bg_color(sensBtn, lv_color_hex(selectedColor), LV_PART_MAIN);
        instance.drv.stop();
        instance.drv.setWaveform(0, buzz1); 
        instance.drv.run();
    }
}

void untoggleBtns() {
    btnSelect = 0;
    lv_obj_set_style_bg_color(maxMIDIbtn, lv_color_hex(grey1), LV_PART_MAIN);
    lv_obj_set_style_bg_color(minMIDIbtn, lv_color_hex(grey1), LV_PART_MAIN);
    lv_obj_set_style_bg_color(CCbtn, lv_color_hex(grey1), LV_PART_MAIN);
    lv_obj_set_style_bg_color(sensBtn, lv_color_hex(grey1), LV_PART_MAIN);
    instance.drv.stop();
    instance.drv.setWaveform(0, buzz2); 
    instance.drv.run();
}



void slider_event_cb(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_VALUE_CHANGED) {
        sliderValue = lv_slider_get_value(slider);  // Update the global slider value
    }
}

void left_button_event_cb(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_CLICKED) {
        instance.drv.stop();
        instance.drv.setWaveform(0, buzz1); 
        instance.drv.run();
        if (inSettings) {
            sliderValue = lv_slider_get_value(slider);
            if (sliderValue > 0) {
                sliderValue--;
                lv_slider_set_value(slider, sliderValue, LV_ANIM_OFF);
            }
        } else {
            xyz = (xyz % 3) + 1;
            setXYZLabel();
        }
    }
}


void right_button_event_cb(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_CLICKED) {
        instance.drv.stop();
        instance.drv.setWaveform(0, buzz1); 
        instance.drv.run();
        if (inSettings) {
            sliderValue = lv_slider_get_value(slider);
            if (sliderValue < 127) {
                sliderValue++;
                lv_slider_set_value(slider, sliderValue, LV_ANIM_OFF);
            }
        } else {
            jolt = !jolt;
            setJoltLabel();
        }
    }
}


void settingsToggler(lv_event_t *e) {
    lv_event_code_t code = lv_event_get_code(e);
    if (code == LV_EVENT_CLICKED) {
        if (!inSettings) {
            inSettings = true;
            hideBalls();
            untoggleBtns();
            lv_obj_add_flag(btnToggleBall, LV_OBJ_FLAG_HIDDEN);
            lv_obj_clear_flag(maxMIDIbtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_clear_flag(minMIDIbtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_clear_flag(CCbtn, LV_OBJ_FLAG_HIDDEN);         
            lv_obj_clear_flag(xyzBtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_clear_flag(joltBtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_clear_flag(sensBtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_add_style(leftIcon, &style_medium_text, 0);
            lv_label_set_text(leftIcon, LV_SYMBOL_LEFT);
            lv_label_set_text(rightIcon, LV_SYMBOL_RIGHT);
            //lv_obj_align(rightIcon, LV_ALIGN_BOTTOM_RIGHT, 5, 5);
            if (xyz == 1) {
                lv_label_set_text_fmt(xyzLabel, "X");
                lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(grey1), LV_PART_MAIN); 
            } else if (xyz == 2) {
                lv_label_set_text_fmt(xyzLabel, "Y");
                lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(grey1), LV_PART_MAIN); 
            } else if (xyz == 3) {
                lv_label_set_text_fmt(xyzLabel, "Z");
                lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(selectedColor), LV_PART_MAIN); 
            }
            if (jolt) {
                lv_obj_set_style_bg_color(joltBtn, lv_color_hex(selectedColor), LV_PART_MAIN);
                lv_label_set_text_fmt(joltLabel, "Jolt: \nON");
            } else {
                lv_obj_set_style_bg_color(joltBtn, lv_color_hex(grey1), LV_PART_MAIN);
                lv_label_set_text_fmt(joltLabel, "Jolt: \nOFF");
            }             
        } else {
            inSettings = false;
            showBalls();
            lv_obj_clear_flag(btnToggleBall, LV_OBJ_FLAG_HIDDEN);
            lv_obj_add_flag(maxMIDIbtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_add_flag(minMIDIbtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_add_flag(CCbtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_add_flag(xyzBtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_add_flag(joltBtn, LV_OBJ_FLAG_HIDDEN);
            lv_obj_add_flag(sensBtn, LV_OBJ_FLAG_HIDDEN);
            setXYZLabel();
            setJoltLabel();
            
        }
    }
}

void setXYZLabel() {
    if (xyz == 1) {
        lv_label_set_text_fmt(leftIcon, "X");
    } else if (xyz == 2) {
        lv_label_set_text_fmt(leftIcon, "Y");
    } else if (xyz == 3) {
        lv_label_set_text_fmt(leftIcon, "Z");
    }
}

void setJoltLabel() {
    if (jolt) {
        lv_label_set_text(rightIcon, LV_SYMBOL_LOOP);
    } else {
        lv_label_set_text(rightIcon, LV_SYMBOL_STOP);
    }
}


void OnDataSent(const wifi_tx_info_t *mac_addr, esp_now_send_status_t status) { // changed from const uint8_t to wifi_tx_info_t for new ESP_NOW library
  sta = (status == ESP_NOW_SEND_SUCCESS);  //sta = (status == ESP_NOW_SEND_SUCCESS) ? "Success" : "Fail";
  //printf("%s\n", sta ? "Success" : "Fail");
}

void loadUI() {
    lv_obj_t *screen = lv_scr_act();
    lv_obj_set_style_bg_color(screen, lv_color_hex(0x000000), LV_PART_MAIN);
    lv_obj_set_scrollbar_mode(screen, LV_SCROLLBAR_MODE_OFF);  // Disable scrollbars 
    lv_obj_add_event_cb(lv_scr_act(), swipe_event_handler, LV_EVENT_GESTURE, NULL);

    lv_style_init(&style_large_text);
    lv_style_set_text_font(&style_large_text, &lv_font_montserrat_30);
    lv_style_init(&style_medium_text);
    lv_style_set_text_font(&style_medium_text, &lv_font_montserrat_24);

    btnToggleBall = lv_btn_create(screen);  //button in background for clicking detection
    lv_obj_set_size(btnToggleBall, 100, 100); 
    lv_obj_align(btnToggleBall, LV_ALIGN_CENTER, 0, 0);
    lv_obj_set_style_bg_color(btnToggleBall, lv_color_hex(0x000000), LV_PART_MAIN); 
    lv_obj_set_style_shadow_width(btnToggleBall, 0, LV_PART_MAIN); 
    lv_obj_set_style_radius(btnToggleBall, 25, LV_PART_MAIN); // make button a circle
    lv_obj_add_event_cb(btnToggleBall, toggleBallCallback, LV_EVENT_LONG_PRESSED, NULL);

    Zball1 = lv_obj_create(screen);
    lv_obj_align(Zball1, LV_ALIGN_CENTER, 0, 0);
    lv_obj_set_style_radius(Zball1, LV_RADIUS_CIRCLE, LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball1, lv_color_hex(red1), LV_PART_MAIN); 
    lv_obj_set_style_border_width(Zball1, 0, LV_PART_MAIN);
    lv_obj_clear_flag(Zball1, LV_OBJ_FLAG_CLICKABLE);   
    lv_obj_clear_flag(Zball1, LV_OBJ_FLAG_ADV_HITTEST);
    lv_obj_clear_flag(Zball1, LV_OBJ_FLAG_SCROLLABLE);  //removes scrollbars when small

    Zball2 = lv_obj_create(screen);
    lv_obj_align(Zball2, LV_ALIGN_CENTER, 0, 0);
    lv_obj_set_style_radius(Zball2, LV_RADIUS_CIRCLE, LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball2, lv_color_hex(red2), LV_PART_MAIN); 
    lv_obj_set_style_border_width(Zball2, 0, LV_PART_MAIN);
    lv_obj_clear_flag(Zball2, LV_OBJ_FLAG_CLICKABLE); 
    lv_obj_clear_flag(Zball2, LV_OBJ_FLAG_ADV_HITTEST);
    lv_obj_clear_flag(Zball2, LV_OBJ_FLAG_SCROLLABLE);  //removes scrollbars when small

    Zball3 = lv_obj_create(screen);
    lv_obj_align(Zball3, LV_ALIGN_CENTER, 0, 0);
    lv_obj_set_style_radius(Zball3, LV_RADIUS_CIRCLE, LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball3, lv_color_hex(red3), LV_PART_MAIN); 
    lv_obj_set_style_border_width(Zball3, 0, LV_PART_MAIN);
    lv_obj_clear_flag(Zball3, LV_OBJ_FLAG_CLICKABLE);   
    lv_obj_clear_flag(Zball3, LV_OBJ_FLAG_ADV_HITTEST);
    lv_obj_clear_flag(Zball3, LV_OBJ_FLAG_SCROLLABLE);  //removes scrollbars when small

    Zball4 = lv_obj_create(screen);
    lv_obj_align(Zball4, LV_ALIGN_CENTER, 0, 0);
    lv_obj_set_style_radius(Zball4, LV_RADIUS_CIRCLE, LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball4, lv_color_hex(red4), LV_PART_MAIN); 
    lv_obj_set_style_border_width(Zball4, 0, LV_PART_MAIN);
    lv_obj_clear_flag(Zball4, LV_OBJ_FLAG_CLICKABLE);   
    lv_obj_clear_flag(Zball4, LV_OBJ_FLAG_ADV_HITTEST);
    lv_obj_clear_flag(Zball4, LV_OBJ_FLAG_SCROLLABLE);  //removes scrollbars when small

    Zball5 = lv_obj_create(screen);
    lv_obj_align(Zball5, LV_ALIGN_CENTER, 0, 0);
    lv_obj_set_style_radius(Zball5, LV_RADIUS_CIRCLE, LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball5, lv_color_hex(red5), LV_PART_MAIN); 
    lv_obj_set_style_border_width(Zball5, 0, LV_PART_MAIN);
    lv_obj_clear_flag(Zball5, LV_OBJ_FLAG_CLICKABLE);   
    lv_obj_clear_flag(Zball5, LV_OBJ_FLAG_ADV_HITTEST);
    lv_obj_clear_flag(Zball5, LV_OBJ_FLAG_SCROLLABLE);  //removes scrollbars when small

    Zball6 = lv_obj_create(screen);
    lv_obj_align(Zball6, LV_ALIGN_CENTER, 0, 0);
    lv_obj_set_style_radius(Zball6, LV_RADIUS_CIRCLE, LV_PART_MAIN); 
    lv_obj_set_style_bg_color(Zball6, lv_color_hex(red6), LV_PART_MAIN); 
    lv_obj_set_style_border_width(Zball6, 0, LV_PART_MAIN);
    lv_obj_clear_flag(Zball6, LV_OBJ_FLAG_CLICKABLE);   
    lv_obj_clear_flag(Zball6, LV_OBJ_FLAG_ADV_HITTEST);
    lv_obj_clear_flag(Zball6, LV_OBJ_FLAG_SCROLLABLE);  //removes scrollbars when small
    

    lv_obj_t *settings = lv_btn_create(screen);
    lv_obj_set_size(settings, 50, 50); 
    lv_obj_align(settings, LV_ALIGN_TOP_LEFT, -5, -5);
    lv_obj_set_style_bg_color(settings, lv_color_hex(0x000000), LV_PART_MAIN); 
    lv_obj_set_style_shadow_width(settings, 0, LV_PART_MAIN); 
    lv_obj_add_event_cb(settings, settingsToggler, LV_EVENT_CLICKED, NULL);
    
    lv_obj_t *settingsIcon = lv_label_create(settings);
    lv_label_set_text(settingsIcon, LV_SYMBOL_SETTINGS);
    lv_obj_set_style_text_color(settingsIcon , lv_color_hex(0xffffff), LV_PART_MAIN);
    lv_obj_add_style(settingsIcon, &style_large_text, 0);
    lv_obj_align(settingsIcon, LV_ALIGN_CENTER, 0, 0);


    pairLabel = lv_label_create(lv_scr_act());
    lv_obj_set_style_text_color(pairLabel , lv_color_hex(0xffffff), LV_PART_MAIN);
    //lv_label_set_recolor(pairLabel, true);  
    lv_obj_add_style(pairLabel, &style_medium_text, 0);
    lv_obj_align(pairLabel, LV_ALIGN_TOP_RIGHT, -5, 5);
    lv_label_set_text_fmt(pairLabel, "...");


    slider = lv_slider_create(screen);
    lv_obj_set_size(slider, 130, 10); 
    lv_obj_align(slider, LV_ALIGN_BOTTOM_MID, 0, -12);
    lv_slider_set_range(slider, 0, 127);
    lv_slider_set_value(slider, sliderValue, LV_ANIM_OFF);
    //lv_obj_add_flag(slider, LV_OBJ_FLAG_HIDDEN); 
    lv_obj_set_ext_click_area(slider, 30); // extra sensitivity 
    lv_obj_add_event_cb(slider, slider_event_cb, LV_EVENT_VALUE_CHANGED, NULL);
    lv_obj_set_style_bg_color(slider, lv_color_hex(grey1), LV_PART_MAIN);

    static lv_style_t style_knob;
    lv_style_init(&style_knob);
    lv_style_set_bg_opa(&style_knob, LV_OPA_TRANSP);
    lv_obj_add_style(slider, &style_knob, LV_PART_KNOB);


    btnLeft = lv_btn_create(screen);
    lv_obj_set_size(btnLeft, 50, 50); 
    lv_obj_align(btnLeft, LV_ALIGN_BOTTOM_LEFT, 0, 0);
    lv_obj_set_style_bg_color(btnLeft, lv_color_hex(0x000000), LV_PART_MAIN); 
    lv_obj_set_style_shadow_width(btnLeft, 0, LV_PART_MAIN); 
    lv_obj_add_event_cb(btnLeft, left_button_event_cb, LV_EVENT_CLICKED, NULL);

    leftIcon = lv_label_create(btnLeft);
    lv_obj_align(leftIcon, LV_ALIGN_BOTTOM_LEFT, -5, 5);
    lv_obj_add_style(leftIcon, &style_large_text, 0);
    setXYZLabel();


    btnRight = lv_btn_create(screen);
    lv_obj_set_size(btnRight, 50, 50); 
    lv_obj_align(btnRight, LV_ALIGN_BOTTOM_RIGHT, 0, 0);
    lv_obj_set_style_bg_color(btnRight, lv_color_hex(0x000000), LV_PART_MAIN); 
    lv_obj_set_style_shadow_width(btnRight, 0, LV_PART_MAIN); 
    lv_obj_add_event_cb(btnRight, right_button_event_cb, LV_EVENT_CLICKED, NULL);

    rightIcon = lv_label_create(btnRight);
    lv_obj_align(rightIcon, LV_ALIGN_BOTTOM_RIGHT, 5, 5);
    lv_obj_add_style(rightIcon, &style_medium_text, 0);
    setJoltLabel();


    maxMIDIbtn = lv_btn_create(screen);
    lv_obj_set_size(maxMIDIbtn, 70, 70); 
    lv_obj_align(maxMIDIbtn, LV_ALIGN_CENTER, 0, 40);
    lv_obj_add_event_cb(maxMIDIbtn, maxMIDIToggler, LV_EVENT_CLICKED, NULL);
    lv_obj_add_flag(maxMIDIbtn, LV_OBJ_FLAG_HIDDEN);

    maxMIDI = lv_label_create(maxMIDIbtn);
    lv_obj_align(maxMIDI, LV_ALIGN_CENTER, 0, 0);
    lv_obj_add_style(maxMIDI, &style_medium_text, 0);
    lv_obj_set_style_text_align(maxMIDI, LV_TEXT_ALIGN_CENTER, 0);


    minMIDIbtn = lv_btn_create(screen);
    lv_obj_set_size(minMIDIbtn, 70, 70); 
    lv_obj_align(minMIDIbtn, LV_ALIGN_CENTER, -80, 40);
    lv_obj_add_event_cb(minMIDIbtn, minMIDIToggler, LV_EVENT_CLICKED, NULL);
    lv_obj_add_flag(minMIDIbtn, LV_OBJ_FLAG_HIDDEN);

    minMIDI = lv_label_create(minMIDIbtn);
    lv_obj_align(minMIDI, LV_ALIGN_CENTER, 0, 0);
    lv_obj_add_style(minMIDI, &style_medium_text, 0);
    lv_obj_set_style_text_align(minMIDI, LV_TEXT_ALIGN_CENTER, 0);


    CCbtn = lv_btn_create(screen);
    lv_obj_set_size(CCbtn, 70, 70); 
    lv_obj_align(CCbtn, LV_ALIGN_CENTER, 80, 40);
    lv_obj_add_event_cb(CCbtn, CCToggler, LV_EVENT_CLICKED, NULL);
    lv_obj_add_flag(CCbtn, LV_OBJ_FLAG_HIDDEN);

    CClabel = lv_label_create(CCbtn);
    lv_obj_align(CClabel, LV_ALIGN_CENTER, 0, 0);
    lv_obj_add_style(CClabel, &style_medium_text, 0);
    lv_obj_set_style_text_align(CClabel, LV_TEXT_ALIGN_CENTER, 0);


    xyzBtn = lv_btn_create(screen);
    lv_obj_set_size(xyzBtn, 70, 70); 
    lv_obj_align(xyzBtn, LV_ALIGN_CENTER, -80, -40);
    lv_obj_add_event_cb(xyzBtn, xyzToggler, LV_EVENT_CLICKED, NULL);
    lv_obj_add_flag(xyzBtn, LV_OBJ_FLAG_HIDDEN);

    xyzLabel = lv_label_create(xyzBtn);
    lv_obj_align(xyzLabel, LV_ALIGN_CENTER, 0, 0);
    lv_obj_add_style(xyzLabel, &style_large_text, 0);
    lv_obj_set_style_text_align(xyzLabel, LV_TEXT_ALIGN_CENTER, 0);
    
  
    joltBtn = lv_btn_create(screen);
    lv_obj_set_size(joltBtn, 70, 70); 
    lv_obj_align(joltBtn, LV_ALIGN_CENTER, 0, -40);
    lv_obj_add_event_cb(joltBtn, joltToggler, LV_EVENT_CLICKED, NULL);
    lv_obj_add_flag(joltBtn, LV_OBJ_FLAG_HIDDEN);

    joltLabel = lv_label_create(joltBtn);
    lv_obj_align(joltLabel, LV_ALIGN_CENTER, 0, 0);
    lv_obj_add_style(joltLabel, &style_medium_text, 0);
    lv_obj_set_style_text_align(joltLabel, LV_TEXT_ALIGN_CENTER, 0);

    sensBtn = lv_btn_create(screen);
    lv_obj_set_size(sensBtn, 70, 70); 
    lv_obj_align(sensBtn, LV_ALIGN_CENTER, 80, -40);
    lv_obj_add_event_cb(sensBtn, sensToggler, LV_EVENT_CLICKED, NULL);
    lv_obj_add_flag(sensBtn, LV_OBJ_FLAG_HIDDEN);

    sensLabel = lv_label_create(sensBtn);
    lv_obj_align(sensLabel, LV_ALIGN_CENTER, 0, 0);
    lv_obj_add_style(sensLabel, &style_medium_text, 0);
    lv_obj_set_style_text_align(sensLabel, LV_TEXT_ALIGN_CENTER, 0);


    lv_style_init(&style_btn_gradient);
    lv_style_set_radius(&style_btn_gradient, 10); // rounded corners
    lv_style_set_bg_opa(&style_btn_gradient, LV_OPA_COVER);
    
    // Set gradient
    lv_style_set_bg_color(&style_btn_gradient, lv_color_hex(red6)); 
    lv_style_set_bg_grad_color(&style_btn_gradient, lv_color_hex(red1)); // red end
    lv_style_set_bg_grad_dir(&style_btn_gradient, LV_GRAD_DIR_VER);

    lv_style_set_border_width(&style_btn_gradient, 0);
    lv_style_set_shadow_width(&style_btn_gradient, 0);

    lv_obj_add_style(maxMIDIbtn, &style_btn_gradient, LV_PART_MAIN);
    lv_obj_add_style(minMIDIbtn, &style_btn_gradient, LV_PART_MAIN);
    lv_obj_add_style(CCbtn, &style_btn_gradient, LV_PART_MAIN);
    lv_obj_add_style(xyzBtn, &style_btn_gradient, LV_PART_MAIN);
    lv_obj_add_style(joltBtn, &style_btn_gradient, LV_PART_MAIN);
    lv_obj_add_style(sensBtn, &style_btn_gradient, LV_PART_MAIN);
    lv_obj_add_style(slider, &style_btn_gradient, LV_PART_INDICATOR);

    setupPresetValues();
}

void setupPresetValues() {
    if (preset == 1) {
        selectedColor = red6;
        backgroundColor = red1;
    } else if (preset == 2) {
        selectedColor = blue6;
        backgroundColor = blue2;
    } else if (preset == 3) {
        selectedColor = purple6;
        backgroundColor = purple1;
    }

    lv_style_set_bg_color(&style_btn_gradient, lv_color_hex(selectedColor)); 
    lv_style_set_bg_grad_color(&style_btn_gradient, lv_color_hex(backgroundColor)); // red end

    untoggleBtns();
    loadPreset();

    lv_label_set_text_fmt(maxMIDI, "Max: \n%d", maxMIDIvalue);
    lv_label_set_text_fmt(minMIDI, "Min: \n%d", minMIDIvalue);
    lv_label_set_text_fmt(CClabel, "CC: \n%d", CC);
    lv_label_set_text_fmt(sensLabel, "Sens: \n%d %%", sensitivity);

    if (!jolt) {
        lv_obj_set_style_bg_color(joltBtn, lv_color_hex(grey1), LV_PART_MAIN);
        lv_label_set_text_fmt(joltLabel, "Jolt: \nOFF");
    } else {
        lv_obj_set_style_bg_color(joltBtn, lv_color_hex(selectedColor), LV_PART_MAIN);
        lv_label_set_text_fmt(joltLabel, "Jolt: \nON");
    }

    if (xyz == 1) {
        lv_label_set_text_fmt(xyzLabel, "X");
        lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(grey1), LV_PART_MAIN); 
    } else if (xyz == 2) {
        lv_label_set_text_fmt(xyzLabel, "Y");
        lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(grey1), LV_PART_MAIN); 
    } else {
        lv_label_set_text_fmt(xyzLabel, "Z");
        lv_obj_set_style_bg_color(xyzBtn, lv_color_hex(selectedColor), LV_PART_MAIN);
    }
}


void savePresetIfChanged() {

    //printf("Checking values: xyz=%d, prev_xyz=%d, CC=%d, prev_CC=%d, maxMIDIvalue=%d, prev_max=%d\n", xyz, prev_xyz, CC, prev_CC, maxMIDIvalue, prev_max);
    
    if (xyz != prev_xyz || CC != prev_CC || maxMIDIvalue != prev_max || 
        minMIDIvalue != prev_min || jolt != prev_jolt || sensitivity != prev_sens) {

        if (preset == 1) {
            pref.begin("Preset1", false);
        } else if (preset == 2) {
            pref.begin("Preset2", false);
        } else if (preset == 3) {
            pref.begin("Preset3", false);
        }

        pref.putShort("xyz", xyz);
        pref.putShort("CC", CC);
        pref.putShort("max", maxMIDIvalue);
        pref.putShort("min", minMIDIvalue);
        pref.putShort("sens", sensitivity);
        pref.putBool("jolt", jolt);
        pref.end();

        //printf("Preset saved!\n");
        }
}

void loadPreset() {
    if (preset == 1) {
        pref.begin("Preset1", true);  // read-only
    } else if (preset == 2) {
        pref.begin("Preset2" ,true);
    } else if (preset == 3) {
        pref.begin("Preset3", true);
    }
    xyz = pref.getShort("xyz", 3);
    CC = pref.getShort("CC", 74);
    maxMIDIvalue = pref.getShort("max", 126);
    minMIDIvalue = pref.getShort("min", 0);
    sensitivity = pref.getShort("sens", 100);
    jolt = pref.getBool("jolt", false);
    pref.end();

    prev_xyz = xyz;
    prev_CC = CC;
    prev_max = maxMIDIvalue;
    prev_min = minMIDIvalue;
    prev_sens = sensitivity;
    prev_jolt = jolt;
}


void setup() {
    instance.begin();
    beginLvglHelper(instance);
    WiFi.mode(WIFI_STA);
    instance.setBrightness(DEVICE_MAX_BRIGHTNESS_LEVEL);

    instance.sensor.configAccelerometer();
    instance.sensor.enableAccelerometer();

    loadPreset();

    prev_xyz = xyz;
    prev_CC = CC;
    prev_max = maxMIDIvalue;
    prev_min = minMIDIvalue;
    prev_sens = sensitivity;
    prev_jolt = jolt;

    loadUI();

    if (esp_now_init() != ESP_OK) {
        lv_label_set_text_fmt(pairLabel, "ESP-NOW Init Failed");
        return;
    }

    esp_now_register_send_cb(OnDataSent);  // Once ESPNow is successfully Init, we will register for Send CB to get the status of Transmitted packet
    esp_now_del_peer(receiverAddress); //Clear old peer
    memcpy(peerInfo.peer_addr, receiverAddress, 6);
    peerInfo.channel = 0;  
    peerInfo.encrypt = false;

    if (esp_now_add_peer(&peerInfo) != ESP_OK) {
        lv_label_set_text_fmt(pairLabel, "Failed to add peer");
        return;
    }   
}

void loop() {
    latency = millis() - lastMillis;

    if (latency >= 20) {
        lastMillis = millis();

        if (inSettings) {
            if (btnSelect == 1) {
                maxMIDIvalue = sliderValue;
                lv_label_set_text_fmt(maxMIDI, "Max: \n%d", maxMIDIvalue); 
            } else if (btnSelect == 2) {
                minMIDIvalue = sliderValue;
                lv_label_set_text_fmt(minMIDI, "Min: \n%d", minMIDIvalue);    
            } else if (btnSelect == 3) {
                CC = sliderValue;
                lv_label_set_text_fmt(CClabel, "CC: \n%d", CC);
            } else if (btnSelect == 4) {
                sensitivity = constrain(sliderValue, 1, 100);
                lv_label_set_text_fmt(sensLabel, "Sens: \n%d %%", sensitivity);
            }
        } else {

            instance.sensor.getAccelerometer(y, x, z);

            smoothedX = alpha * -x + (1 - alpha) * smoothedX;  // reverse x
            smoothedY = alpha * y + (1 - alpha) * smoothedY;
            smoothedZ = alpha * z + (1 - alpha) * smoothedZ;   // Apply exponential smoothing

            detectXJolt();
        }


        if (!toggleBall) { 
            if (xyz == 1) {
                data = smoothedX;
            } else if (xyz == 2) {
                data = -smoothedY;  // reverse y data but not for visual
            } else if (xyz == 3) {
                data = smoothedZ;
            }

            myData.info = CC; 

            myData.midi = map(constrain(map(data, -sensitivity*5, sensitivity*5, 0, 127), 0, 127), 0, 127, minMIDIvalue, maxMIDIvalue);

            esp_err_t result = esp_now_send(receiverAddress, (uint8_t *)&myData, sizeof(myData));   // Send the MIDI message via ESP-NOW

            if (!inSettings) {
                lv_slider_set_value(slider, myData.midi, LV_ANIM_OFF);
            }

        } 
        
        /*else {
      
          lastSend = true; 
          if (lastSend) {
              esp_err_t result = esp_now_send(receiverAddress, (uint8_t *)&myData, sizeof(myData));  // Ensures that the final Max/Min message is sent after a jolt
          }
          lastSend = false; 
    }
*/


    
    if (sta) {
        lv_label_set_text_fmt(pairLabel, LV_SYMBOL_WIFI);
        wasConnected = true;
        disconnected = false;
    } else if (wasConnected) {
            disconnectionTime = millis();  // Start the disconnection timer
            wasConnected = false;
            disconnected = true;
    } else if (disconnected) {
        if (millis() - disconnectionTime >= 10000) {    // Check if 15 seconds have passed since disconnection started
            lv_label_set_text(pairLabel, ":( ");
        }
    }

    
    mapX1 = smoothedX / 18;
    mapX2 = smoothedX / 16;
    mapX3 = smoothedX / 14;
    mapX4 = smoothedX / 12;
    mapX5 = smoothedX / 10;
    mapX6 = smoothedX / 9;

    mapY1 = smoothedY / 18;
    mapY2 = smoothedY / 16;
    mapY3 = smoothedY / 14;
    mapY4 = smoothedY / 12;
    mapY5 = smoothedY / 10;
    mapY6 = smoothedY / 9;

    Zball1map = map(smoothedZ, -500, 500, 80, 200);
    lv_obj_set_size(Zball1, Zball1map, Zball1map); 
    lv_obj_align(Zball1, LV_ALIGN_CENTER, 0 + mapX1, 0 +mapY1);

    Zball2map = map(smoothedZ, -500, 500, 70, 190);
    lv_obj_set_size(Zball2, Zball2map, Zball2map); 
    lv_obj_align(Zball2, LV_ALIGN_CENTER, 0 + mapX2, 0 +mapY2);

    Zball3map = map(smoothedZ, -500, 500, 60, 160);
    lv_obj_set_size(Zball3, Zball3map, Zball3map); 
    lv_obj_align(Zball3, LV_ALIGN_CENTER, 0 + mapX3, 0 + mapY3);

    Zball4map = map(smoothedZ, -500, 500, 50, 140);
    lv_obj_set_size(Zball4, Zball4map, Zball4map); 
    lv_obj_align(Zball4, LV_ALIGN_CENTER, 0 + mapX4, 0 + mapY4);

    Zball5map = map(smoothedZ, -500, 500, 40, 120);
    lv_obj_set_size(Zball5, Zball5map, Zball5map); 
    lv_obj_align(Zball5, LV_ALIGN_CENTER, 0 + mapX5, 0 +mapY5);

    Zball6map = map(smoothedZ, -500, 500, 30, 90);
    lv_obj_set_size(Zball6, Zball6map, Zball6map); 
    lv_obj_align(Zball6, LV_ALIGN_CENTER, 0 + mapX6, 0 +mapY6);


    lv_timer_handler();  // changed from lv_task_handler for lvgl 9.2.2
    }   
}