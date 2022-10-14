//test what println sends out
int analogValue = 0;   
int digitalValue = 0;

//this define code allows to add logging if required
#define DEBUG
#ifdef DEBUG
  #define log(...)  Serial.println(__VA_ARGS__)   
  #define logv(x)  Serial.print(F(#x" = ")); Serial.print(x); Serial.println (F(" ")); 
#else
  #define log(...)
  #define logv(x)
#endif

void setup() {
  // open the serial port at 9600 bps:
  Serial.begin(9600);
  pinMode(2,INPUT);
  pinMode(3,INPUT);
}

void loop() {
  // read the analog input on pin 0:
  
  analogValue = analogRead(2);
  digitalValue = digitalRead(3);

  // print it out in many formats:
  Serial.println(F("Analog Data"));
  Serial.println(analogValue);       // print as an ASCII-encoded decimal
  Serial.println(analogValue, DEC);  // print as an ASCII-encoded decimal
  Serial.println(analogValue, HEX);  // print as an ASCII-encoded hexadecimal
  Serial.println(analogValue, OCT);  // print as an ASCII-encoded octal
  Serial.println(analogValue, BIN);  // print as an ASCII-encoded binary

  // print it out in many formats:
  Serial.println(F("Digital Data"));
  Serial.println(digitalValue);       // print as an ASCII-encoded decimal
  Serial.println(digitalValue, DEC);  // print as an ASCII-encoded decimal
  Serial.println(digitalValue, HEX);  // print as an ASCII-encoded hexadecimal
  Serial.println(digitalValue, OCT);  // print as an ASCII-encoded octal
  Serial.println(digitalValue, BIN);  // print as an ASCII-encoded binary
  
  Serial.flush();
  
  // delay 10 milliseconds before the next reading:
  delay(500);
}