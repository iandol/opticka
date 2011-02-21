//#include <AikoEvents.h>
//using namespace Aiko;

//This define is used to set the analogread multiplier to read more quickly.
#ifndef cbi 
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit)) 
#endif 
#ifndef sbi 
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit)) 
#endif

//unsigned long time = 0;
//unsigned long timebefore = 0;
//unsigned long timedifference = 0;
const int ledPin = 13;
  const int analogInPin = 0;  // Analog input pin that the potentiometer is attached to
const int potPin = 1;
//const int analogOutPin = 9; // Analog output pin that the LED is attached to
//int ledState = LOW;
//int other = HIGH;
int sensorValue = 0;        // value read from the pd
int potValue = 0;          // value from the 10K pot
int outputValue = 0;        // value output to the PWM (analog out)

void setup(){
  sbi(ADCSRA, ADPS2); //analogRead multiplier is 16, much faster...
  cbi(ADCSRA, ADPS1); 
  cbi(ADCSRA, ADPS0);
  Serial.begin(2400);
  pinMode(ledPin, OUTPUT); 
  //Events.addHandler(blinky, 13);  // Every 13ms, equivalent to a 75hz signal
}
void loop(){ 
  //Events.loop();
  sensorValue = analogRead(analogInPin);  
  potValue = analogRead(potPin) -150;  
  potValue = constrain(potValue, 0, 850);
  outputValue = map(sensorValue, 0, 850, 0, 255);
  outputValue = constrain(outputValue, 0, 255);
  if (sensorValue > potValue) {
    togled(HIGH);
  }
  else {
    togled(LOW);
  }
  //analogWrite(analogOutPin, outputValue);
  //time = Timing.millis(); //micros();
  //timedifference = time-timebefore;
  //Serial.print("Time:");
  //Serial.print(time);
  //Serial.print("\tDiff:");
  //Serial.print(timedifference);
  Serial.print("Sensor: ");  
  Serial.print(sensorValue);
  Serial.print("\tOut: ");  
  Serial.print(outputValue);
  Serial.print("\tPot: ");
  Serial.println(potValue);
  

  //if (ledState == LOW) {
  //    ledState = HIGH;
  //    PORTB = PORTB | B00100000;
  // }
  // else {
  //   ledState = LOW;
  //   PORTB &= ~(1 << 5); //this bitshifts to create turn off bit 6 only
  //}
  // set the LED with the ledState of the variable:
  //digitalWrite(ledPin, ledState);
  //digitalWrite(ledPin2, other);
  //analogWrite(analogOutPin, outputValue); 
  //timebefore = time;
  //delay(10);
}

void togled(boolean toggle) {
  //static boolean toggle = HIGH;
  static boolean on = HIGH;

  if (toggle == LOW) {
    PORTB &= ~(1 << 5); //this bitshifts to turn off bit 6 only
  }
  else {
    PORTB = PORTB | B00100000;
  }  
  //digitalWrite(ledPin, on);
  //on = !on;
  //toggle = LOW;
}

void blinky() {
  static boolean on = LOW;  
  if (on == LOW) {
    PORTB &= ~(1 << 5); //this bitshifts to turn off bit 6 only
  }
  else {
    PORTB = PORTB | B00100000;
  }  
  //digitalWrite(ledPin, on);
  on = !on;

}


