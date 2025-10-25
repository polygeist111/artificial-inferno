 // Added 5-pin Midi Out
 // requires MIDI Library 4.3.1 to work with Adafruit_TinyUSB 2.4.0 and esp32 core 2.0.17
 // USB CDC on boot
 // USB mode: USB-OTG(TinyUSB)


#include <Arduino.h>
#include <Adafruit_TinyUSB.h>
#include <MIDI.h>
#include <esp_now.h>
#include <WiFi.h>
#include <HardwareSerial.h>

#define RX_PIN D7 //44 esp-s3-zero
#define TX_PIN D6 //43   // the pin that will physically drive MIDI DIN pin 5

Adafruit_USBD_MIDI usb_midi;  // USB MIDI object

MIDI_CREATE_INSTANCE(Adafruit_USBD_MIDI, usb_midi, MIDI);  // Create a new instance of the Arduino MIDI Library, and attach usb_midi as the transport.

bool ledON = false;
int8_t channel = 74;
int8_t previousMidi; // Store the previous midi value


typedef struct struct_message {
    uint8_t midi;  // Must match the sender structure
    uint8_t info;
} struct_message;

struct_message myData;  // Create a struct_message called myData

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  WiFi.mode(WIFI_STA);
  TinyUSBDevice.setManufacturerDescriptor("BioSynth");
  TinyUSBDevice.setProductDescriptor("BioSynth MIDI");
  //usb_midi.setStringDescriptor("BioSynth MIDI");
  usb_midi.begin();
  Serial.begin(9600);
  Serial1.begin(31250, SERIAL_8N1, RX_PIN, TX_PIN);

  if (TinyUSBDevice.mounted()) {
    TinyUSBDevice.detach();
    delay(10);
    TinyUSBDevice.attach();
  }

  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW Init Failed");
    return;
  }

  esp_now_register_recv_cb(onDataRecv);

  delay(2000);

  Serial.println("ESP-NOW Receiver Initialized");
  Serial.print("MAC: ");
  Serial.println(WiFi.macAddress());

  MIDI.begin();

  delay(1000);
}

void loop() {
  if (!TinyUSBDevice.mounted()) {
    digitalWrite(LED_BUILTIN, HIGH);  // HIGH actually means off
    ledON = false;
    return;  // not enumerated()/mounted() yet: nothing to do
  } 
  delay(1000);
}


void onDataRecv(const esp_now_recv_info *recv_info, const uint8_t *data, int len) {
    // You can optionally retrieve the sender's MAC address like this:
    // const uint8_t *mac = recv_info->src_addr; 
    
    // The rest of your logic remains the same, as 'data' and 'len' are unchanged.
    memcpy(&myData, data, sizeof(myData));

    if (myData.midi != previousMidi) {  // Only send MIDI if the value has changed
        if (ledON) {
            digitalWrite(LED_BUILTIN, HIGH);
        } else {
            digitalWrite(LED_BUILTIN, LOW);
        } 
        ledON = !ledON;
        
        if (myData.info <= 127) {
            MIDI.sendControlChange(myData.info, myData.midi, 1);
            sendDinCC(myData.info, myData.midi, 1);
            previousMidi = myData.midi; // Update the previous value
        } else if (myData.info > 127) {
            Serial.write("channel/mode info");
        }
    }
    //Serial.write(myData.midi);
}

// Send a MIDI Control Change (CC) message over Serial1
void sendDinCC(byte controller, byte value, byte channel) {
  byte status = 0xB0 | ((channel - 1) & 0x0F);  // 0xB0 = CC, channel offset

  Serial1.write(status);      // CC status + channel
  Serial1.write(controller);  // controller number
  Serial1.write(value);       // controller value
}

