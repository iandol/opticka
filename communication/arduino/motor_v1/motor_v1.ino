
/* Analog and Digital Input and Output Server for MATLAB     */
/* Giampiero Campa, Copyright 2012 The MathWorks, Inc        */
 
/* This file is meant to be used with the MATLAB arduino IO 
   package, however, it can be used from the IDE environment
   (or any other serial terminal) by typing commands like:
   
   0e0   : assigns digital pin #4 (e) as input
   0f1   : assigns digital pin #5 (f) as output
   0n1   : assigns digital pin #13 (n) as output   
   
   1c    : reads digital pin #2 (c) 
   1e    : reads digital pin #4 (e) 
   2n0   : sets digital pin #13 (n) low
   2n1   : sets digital pin #13 (n) high
   2f1   : sets digital pin #5 (f) high
   2f0   : sets digital pin #5 (f) low
   4j2   : sets digital pin #9 (j) to  50=ascii(2) over 255
   4jz   : sets digital pin #9 (j) to 122=ascii(z) over 255
   3a    : reads analog pin #0 (a) 
   3f    : reads analog pin #5 (f) 

   5j    : reads status (attached/detached) of servo on pin #9
   5k    : reads status (attached/detached) of servo on pin #10
   6j1   : attaches servo on pin #9
   8jz   : moves servo on pin #9 of 122 degrees (122=ascii(z))
   7j    : reads angle of servo on pin #9
   6j0   : detaches servo on pin #9

   A1z   : sets speed of motor #1 to 122 over 255  (122=ascii(z))
   A4A   : sets speed of motor #4 to 65 over 255 (65=ascii(A))
   B1f   : runs motor #1 forward (f=forward)
   B4b   : runs motor #4 backward (b=backward)
   B1r   : releases motor #1 (r=release)

   C12   : sets speed of stepper motor #1 to 50 rpm  (50=ascii(2))
   C2Z   : sets speed of stepper motor #2 to 90 rpm  (90=ascii(Z))
   D1fsz : does 122 steps on motor #1 forward in single (s) mode 
   D1biA : does 65 steps on motor #1 backward in interleave (i) mode 
   D2fdz : does 122 steps on motor #1 forward in double (d) mode 
   D2bmA : does 65 steps on motor #2 backward in microstep (m) mode 
   D1r   : releases motor #1 (r=release)
   D2r   : releases motor #2 (r=release)

   E0cd  : attaches encoder #0 (0) on pins 2 (c) and 3 (d)
   E1st  : attaches encoder #1 on pins 18 (s) and 19 (t)
   E2vu  : attaches encoder #2 on pins 21 (v) and 20 (u)
   G0    : gets 0 position of encoder #0
   I0u   : sets debounce delay to 20 (2ms) for encoder #0
   H1    : resets position of encoder #1
   F2    : detaches encoder #2
   
   R0    : sets analog reference to DEFAULT
   R1    : sets analog reference to INTERNAL
   R2    : sets analog reference to EXTERNAL
  
   X3    : roundtrip example case returning the input (ascii(3)) 
   99    : returns script type (0 adio.pde ... 3 motor.pde ) */

#include <AFMotor.h>
#include <Servo.h>

/* define internal for the MEGA as 1.1V (as as for the 328)  */
#if defined(__AVR_ATmega1280__) || defined(__AVR_ATmega2560__)
#define INTERNAL INTERNAL1V1
#endif

/* define encoder structure                                  */
typedef struct { int pinA; int pinB; int pos; int del;} Encoder;    
volatile Encoder Enc[3] = {{0,0,0,0}, {0,0,0,0}, {0,0,0,0}};

//* create servo vector                                      */
Servo servo[70];

/* create and initialize motors                              */
AF_Stepper stm1(200, 1);
AF_Stepper stm2(200, 2);
AF_DCMotor dcm1(1, MOTOR12_64KHZ); /* dc motor #1, 64KHz pwm */
AF_DCMotor dcm2(2, MOTOR12_64KHZ); /* dc motor #2, 64KHz pwm */
AF_DCMotor dcm3(3, MOTOR12_64KHZ); /* dc motor #3, 64KHz pwm */
AF_DCMotor dcm4(4, MOTOR12_64KHZ); /* dc motor #4, 64KHz pwm */

void setup() {
  /* initialize serial                                       */
  Serial.begin(115200);
}


void loop() {
  
  /* variables declaration and initialization                */
  
  static int  s   = -1;    /* state                          */
  static int  pin = 13;    /* generic pin number             */
  static int  dcm =  4;    /* generic dc motor number        */

  static int  stm =  2;    /* generic stepper motor number   */
  static int  dir =  0;    /* direction (stepper)            */
  static int  sty =  0;    /* style (stepper)                */

  static int  enc = 0;     /* generic encoder number         */

  int  val =  0;           /* generic value read from serial */
  int  agv =  0;           /* generic analog value           */
  int  dgv =  0;           /* generic digital value          */

  /* The following instruction constantly checks if anything 
     is available on the serial port. Nothing gets executed in 
     the loop if nothing is available to be read, but as soon 
     as anything becomes available, then the part coded after 
     the if statement (that is the real stuff) gets executed */

  if (Serial.available() >0) {

    /* whatever is available from the serial is read here    */
    val = Serial.read();
    
    /* This part basically implements a state machine that 
       reads the serial port and makes just one transition 
       to a new state, depending on both the previous state 
       and the command that is read from the serial port. 
       Some commands need additional inputs from the serial 
       port, so they need 2 or 3 state transitions (each one
       happening as soon as anything new is available from 
       the serial port) to be fully executed. After a command 
       is fully executed the state returns to its initial 
       value s=-1                                            */

    switch (s) {
		
    
      /* s=-1 means NOTHING RECEIVED YET ******************* */
      case -1:      

      /* calculate next state when s=-1                      */
      if (val>47 && val<90) {
	  /* the first received value indicates the mode       
           49 is ascii for 1, ... 90 is ascii for Z          
           s=0 is change-pin mode;
           s=10 is DI;  s=20 is DO;  s=30 is AI;  s=40 is AO; 
           s=50 is servo status; s=60 is aervo attach/detach;  
           s=70 is servo read;   s=80 is servo write;
           s=90 is query script type (1 basic, 2 motor);
           s=170 is dc motor set speed;
           s=180 is dc motor run/release;
           s=190 is stepper motor set speed;
           s=200 is stepper motor run/release;
           s=210 is encoder attach; s=220 is encoder detach;
           s=230 is get encoder position; s=240 is encoder reset;
           s=250 is set encoder debounce delay;
           s=340 is change analog reference;         
           s=400 example echo returning the input argument;
                                                             */
        s=10*(val-48);
      }
      
      /* the following statements are needed to handle 
         unexpected first values coming from the serial (if 
         the value is unrecognized then it defaults to s=-1) */
      if ((s>90 && s<170) || (s>250 && s!=340 && s!=400)) {
        s=-1;
      }
      
      /* the break statements gets out of the switch-case, so 
      /* we go back and wait for new serial data             */
      break; /* s=-1 (initial state) taken care of           */

	  
     
      /* s=0 or 1 means CHANGE PIN MODE                      */
      
      case 0:
      /* the second received value indicates the pin 
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        s=1; /* next we will need to get 0 or 1 from serial  */
      } 
      else {
        s=-1; /* if value is not a pin then return to -1     */
      }
      break; /* s=0 taken care of                            */


      case 1:
      /* the third received value indicates the value 0 or 1 */ 
      if (val>47 && val<50) {
        /* set pin mode                                      */
        if (val==48) {
          pinMode(pin,INPUT);
        }
        else {
          pinMode(pin,OUTPUT);
        }
      }
      s=-1;  /* we are done with CHANGE PIN so go to -1      */
      break; /* s=1 taken care of                            */
      


      /* s=10 means DIGITAL INPUT ************************** */
      
      case 10:
      /* the second received value indicates the pin 
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        dgv=digitalRead(pin);      /* perform Digital Input  */
        Serial.println(dgv);       /* send value via serial  */
      }
      s=-1;  /* we are done with DI so next state is -1      */
      break; /* s=10 taken care of                           */
      


      /* s=20 or 21 means DIGITAL OUTPUT ******************* */
      
      case 20:
      /* the second received value indicates the pin 
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        s=21; /* next we will need to get 0 or 1 from serial */
      } 
      else {
        s=-1; /* if value is not a pin then return to -1     */
      }
      break; /* s=20 taken care of                           */

      case 21:
      /* the third received value indicates the value 0 or 1 */
      if (val>47 && val<50) {
        dgv=val-48;                /* calculate value        */
	digitalWrite(pin,dgv);     /* perform Digital Output */
      }
      s=-1;  /* we are done with DO so next state is -1      */
      break; /* s=21 taken care of                           */


	
      /* s=30 means ANALOG INPUT *************************** */
      
      case 30:
      /* the second received value indicates the pin 
         from abs('a')=97, pin 0, to abs('p')=112, pin 15    */
      if (val>96 && val<113) {
        pin=val-97;                /* calculate pin          */
        agv=analogRead(pin);       /* perform Analog Input   */
	Serial.println(agv);       /* send value via serial  */
      }
      s=-1;  /* we are done with AI so next state is -1      */
      break; /* s=30 taken care of                           */

	

      /* s=40 or 41 means ANALOG OUTPUT ******************** */
      
      case 40:
      /* the second received value indicates the pin 
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        s=41; /* next we will need to get value from serial  */
      }
      else {
        s=-1; /* if value is not a pin then return to -1     */
      }
      break; /* s=40 taken care of                           */


      case 41:
      /* the third received value indicates the analog value */
      analogWrite(pin,val);        /* perform Analog Output  */
      s=-1;  /* we are done with AO so next state is -1      */
      break; /* s=41 taken care of                           */


      
      /* s=50 means SERVO STATUS (ATTACHED/DETACHED) ******* */
      
      case 50:
      /* the second value indicates the servo attachment pin
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        dgv=servo[pin].attached();            /* read status */
        Serial.println(dgv);       /* send value via serial  */
      }
      s=-1;  /* we are done with servo status so return to -1*/
      break; /* s=50 taken care of                           */
      


      /* s=60 or 61 means SERVO ATTACH/DETACH ************** */
      
      case 60:
      /* the second value indicates the servo attachment pin
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        s=61; /* next we will need to get 0 or 1 from serial */
      } 
      else {
        s=-1; /* if value is not a servo then return to -1   */
      }
      break; /* s=60 taken care of                           */


      case 61:
      /* the third received value indicates the value 0 or 1 
         0 for detach and 1 for attach                       */ 
      if (val>47 && val<50) {
        dgv=val-48;                /* calculate value        */
        if (dgv) servo[pin].attach(pin);     /* attach servo */
        else servo[pin].detach();            /* detach servo */
      }
      s=-1;  /* we are done with servo attach/detach so -1   */
      break; /* s=61 taken care of                           */



      /* s=70 means SERVO READ ***************************** */
      
      case 70:
      /* the second value indicates the servo attachment pin
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        agv=servo[pin].read();     /* read value             */
	Serial.println(agv);       /* send value via serial  */
      }
      s=-1;  /* we are done with servo read so go to -1 next */
      break; /* s=70 taken care of                           */



      /* s=80 or 81 means SERVO WRITE   ******************** */
      
      case 80:
      /* the second value indicates the servo attachment pin
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        s=81; /* next we will need to get value from serial  */
      }
      else {
        s=-1; /* if value is not a servo then return to -1   */
      }
      break; /* s=80 taken care of                           */


      case 81:
      /* the third received value indicates the servo angle  */ 
      servo[pin].write(val);                  /* write value */
      s=-1;  /* we are done with servo write so go to -1 next*/
      break; /* s=81 taken care of                           */         


      
      /* s=90 means Query Script Type: 
         (0 adio, 1 adioenc, 2 adiosrv, 3 motor)             */

      case 90:
      if (val==57) { 
        /* if string sent is 99  send script type via serial */
        Serial.println(3);
      }
      s=-1;  /* we are done with this so next state is -1    */
      break; /* s=90 taken care of                           */



      /* s=170 or 171 means DC MOTOR SET SPEED  ************ */
      
      case 170:
      /* the second received value indicates the motor number
         from abs('1')=49, motor1, to abs('4')=52, motor4    */
      if (val>48 && val<53) {
        dcm=val-48;                /* calculate motor number */
        s=171; /* next we will need to get value from serial */
      }
      else {
        s=-1; /* if value is not a motor then return to -1   */
      }
      break; /* s=170 taken care of                          */


      case 171:
      /* the third received value indicates the motor speed  */
      if (dcm==1) dcm1.setSpeed(val);
      if (dcm==2) dcm2.setSpeed(val);
      if (dcm==3) dcm3.setSpeed(val);
      if (dcm==4) dcm4.setSpeed(val);            
      s=-1;  /* we are done with servo write so go to -1 next*/
      break; /* s=171 taken care of                          */



      /* s=180 or 181 means DC MOTOR RUN/RELEASE  ********** */
      case 180:
      /* the second received value indicates the motor number
         from abs('1')=49, motor1, to abs('4')=52, motor4    */
      if (val>48 && val<53) {
        dcm=val-48;                /* calculate motor number */
        s=181; /* next we will need to get value from serial */
      }
      else {
        s=-1; /* if value is not a motor then return to -1   */
      }
      break; /* s=180 taken care of                          */

      case 181:
      /* the third received value indicates forward, backward,
         release, with characters 'f', 'b', 'r', respectively,
         that have ascii codes 102, 98 and 114               */
      if (dcm==1) {
        if (val==102) dcm1.run(FORWARD);
        if (val==98)  dcm1.run(BACKWARD);
        if (val==114) dcm1.run(RELEASE);
      }
      if (dcm==2) {
        if (val==102) dcm2.run(FORWARD);
        if (val==98)  dcm2.run(BACKWARD);
        if (val==114) dcm2.run(RELEASE);
      }
      if (dcm==3) {
        if (val==102) dcm3.run(FORWARD);
        if (val==98)  dcm3.run(BACKWARD);
        if (val==114) dcm3.run(RELEASE);
      }
      if (dcm==4) {
        if (val==102) dcm4.run(FORWARD);
        if (val==98)  dcm4.run(BACKWARD);
        if (val==114) dcm4.run(RELEASE);
      }
      s=-1;  /* we are done with motor run so go to -1 next  */
      break; /* s=181 taken care of                          */



      /* s=190 or 191 means STEPPER MOTOR SET SPEED  ******* */
      
      case 190:
      /* the second received value indicates the motor number
         from abs('1')=49, motor1, to abs('2')=50, motor4    */
      if (val>48 && val<51) {
        stm=val-48;                /* calculate motor number */
        s=191; /* next we will need to get value from serial */
      }
      else {
        s=-1; /* if value is not a stepper then return to -1 */
      }
      break; /* s=190 taken care of                          */


      case 191:
      /* the third received value indicates the speed in rpm */ 
      if (stm==1) stm1.setSpeed(val);
      if (stm==2) stm2.setSpeed(val);
            
      s=-1;  /* we are done with set speed so go to -1 next  */
      break; /* s=191 taken care of                          */



      /* s=200 or 201 means STEPPER MOTOR STEP/RELEASE  **** */
      
      case 200:
      /* the second received value indicates the motor number
         from abs('1')=49, motor1, to abs('2')=50, motor4    */
      if (val>48 && val<51) {
        stm=val-48;                /* calculate motor number */
        s=201;            /* we still need stuff from serial */
      }
      else {
        s=-1; /* if value is not a motor then return to -1   */
      }
      break; /* s=200 taken care of                          */


      case 201:
      /* the third received value indicates forward, backward,
         release, with characters 'f', 'b', 'r', respectively,
         that have ascii codes 102, 98 and 114               */
      switch (val) {
        
        case 102:
        dir=FORWARD;
        s=202;
        break;        
        
        case 98:
        dir=BACKWARD;
        s=202;
        break;        
        
        case 114: /* release and return to -1 here           */
        if (stm==1) stm1.release();
        if (stm==2) stm2.release();
        s=-1;        
        break;
        
        default:
        s=-1;  /* unrecognized  character, go to -1          */
        break;
      } 
      break; /* s=201 taken care of                          */


      case 202:
      /* the third received value indicates the style, single,
         double, interleave, microstep, 's', 'd', 'i', 'm'
         that have ascii codes 115,100,105 and 109           */
      switch (val) {
        
        case 115:
        sty=SINGLE;
        s=203;
        break;
        
        case 100:
        sty=DOUBLE;
        s=203;
        break;
        
        case 105:
        sty=INTERLEAVE;
        s=203;
        break;
        
        case 109:
        sty=MICROSTEP;
        s=203;
        break;
        
        default:
        s=-1;  /* unrecognized  character, go to -1          */
        break;
      } 
      break; /* s=201 taken care of                          */


      case 203:
      /* the last received value indicates the number of 
         steps,                                              */
      if (stm==1) stm1.step(val,dir,sty);  /* do the steps   */
      if (stm==2) stm2.step(val,dir,sty);
      s=-1;        /* we are done with step so go to -1 next */
      break;       /* s=203 taken care of                    */
      

      
      /* s=210 to 212 means ENCODER ATTACH ***************** */
      
      case 210:
      /* the second value indicates the encoder number:
         either 0, 1 or 2                                    */
      if (val>47 && val<51) {
        enc=val-48;        /* calculate encoder number       */
        s=211;  /* next we need the first attachment pin     */
      } 
      else {
        s=-1; /* if value is not an encoder then return to -1*/
      }
      break; /* s=210 taken care of                           */


      case 211:
      /* the third received value indicates the first pin     
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        Enc[enc].pinA=pin;         /* set pin A              */
        s=212;  /* next we need the second attachment pin    */
      } 
      else {
        s=-1; /* if value is not a servo then return to -1   */
      }
      break; /* s=211 taken care of                          */


      case 212:
      /* the fourth received value indicates the second pin     
         from abs('c')=99, pin 2, to abs('¦')=166, pin 69    */
      if (val>98 && val<167) {
        pin=val-97;                /* calculate pin          */
        Enc[enc].pinB=pin;         /* set pin B              */
        
        /* set encoder pins as inputs */
        pinMode(Enc[enc].pinA, INPUT); 
        pinMode(Enc[enc].pinB, INPUT); 
        
        /* turn on pullup resistors */
        digitalWrite(Enc[enc].pinA, HIGH); 
        digitalWrite(Enc[enc].pinB, HIGH); 
        
        /* attach interrupts */
        switch(enc) {
          case 0:
            attachInterrupt(getIntNum(Enc[0].pinA), isrPinAEn0, CHANGE);
            attachInterrupt(getIntNum(Enc[0].pinB), isrPinBEn0, CHANGE);
            break;  
          case 1:
            attachInterrupt(getIntNum(Enc[1].pinA), isrPinAEn1, CHANGE);
            attachInterrupt(getIntNum(Enc[1].pinB), isrPinBEn1, CHANGE);
            break;  
          case 2:
            attachInterrupt(getIntNum(Enc[2].pinA), isrPinAEn2, CHANGE);
            attachInterrupt(getIntNum(Enc[2].pinB), isrPinBEn2, CHANGE);
            break;  
          }
        
      } 
      s=-1; /* we are done with encoder attach so -1         */
      break; /* s=212 taken care of                          */


      /* s=220 means ENCODER DETACH  *********************** */
      
      case 220:
      /* the second value indicates the encoder number:
         either 0, 1 or 2                                    */
      if (val>47 && val<51) {
        enc=val-48;        /* calculate encoder number       */
        /* detach interrupts */
        detachInterrupt(getIntNum(Enc[enc].pinA));
        detachInterrupt(getIntNum(Enc[enc].pinB));
      }
      s=-1;  /* we are done with encoder detach so -1        */
      break; /* s=220 taken care of                          */


      /* s=230 means GET ENCODER POSITION ****************** */
      
      case 230:
      /* the second value indicates the encoder number:
         either 0, 1 or 2                                    */
      if (val>47 && val<51) {
        enc=val-48;        /* calculate encoder number       */
        /* send the value back                               */
        Serial.println(Enc[enc].pos);
      }
      s=-1;  /* we are done with encoder detach so -1        */
      break; /* s=230 taken care of                          */


      /* s=240 means RESET ENCODER POSITION **************** */
      
      case 240:
      /* the second value indicates the encoder number:
         either 0, 1 or 2                                    */
      if (val>47 && val<51) {
        enc=val-48;        /* calculate encoder number       */
        /* reset position                                    */
        Enc[enc].pos=0;
      }
      s=-1;  /* we are done with encoder detach so -1        */
      break; /* s=240 taken care of                          */


      /* s=250 and 251 mean SET ENCODER DEBOUNCE DELAY ***** */
      
      case 250:
      /* the second value indicates the encoder number:
         either 0, 1 or 2                                    */
      if (val>47 && val<51) {
        enc=val-48;        /* calculate encoder number       */
        s=251;  /* next we need the first attachment pin     */
      } 
      else {
        s=-1; /* if value is not an encoder then return to -1*/
      }
      break; /* s=250 taken care of                          */


      case 251:
      /* the third received value indicates the debounce 
         delay value in units of approximately 0.1 ms each 
         from abs('a')=97, 0 units, to abs('¦')=166, 69 units*/
      if (val>96 && val<167) {
        Enc[enc].del=val-97;       /* set debounce delay     */
      }
      s=-1;  /* we are done with this so next state is -1    */
      break; /* s=251 taken care of                          */



      /* s=340 or 341 means ANALOG REFERENCE *************** */
      
      case 340:
      /* the second received value indicates the reference,
         which is encoded as is 0,1,2 for DEFAULT, INTERNAL  
         and EXTERNAL, respectively. Note that this function 
         is ignored for boards not featuring AVR or PIC32    */
         
#if defined(__AVR__) || defined(__PIC32MX__)

      switch (val) {
        
        case 48:
        analogReference(DEFAULT);
        break;        
        
        case 49:
        analogReference(INTERNAL);
        break;        
                
        case 50:
        analogReference(EXTERNAL);
        break;        
        
        default:                 /* unrecognized, no action  */
        break;
      } 

#endif

      s=-1;  /* we are done with this so next state is -1    */
      break; /* s=341 taken care of                          */



      /* s=400 roundtrip example function (returns the input)*/
      
      case 400:
      /* the second value (val) can really be anything here  */
      
      /* This is an auxiliary function that returns the ASCII 
         value of its first argument. It is provided as an 
         example for people that want to add their own code  */
         
      /* your own code goes here instead of the serial print */
      Serial.println(val);

      s=-1;  /* we are done with the aux function so -1      */
      break; /* s=400 taken care of                          */



      /* ******* UNRECOGNIZED STATE, go back to s=-1 ******* */
      
      default:
      /* we should never get here but if we do it means we 
         are in an unexpected state so whatever is the second 
         received value we get out of here and back to s=-1  */
      
      s=-1;  /* go back to the initial state, break unneeded */



    } /* end switch on state s                               */

  } /* end if serial available                               */
  
} /* end loop statement                                      */




/* auxiliary function to handle encoder attachment           */
int getIntNum(int pin) {
/* returns the interrupt number for a given interrupt pin 
   see http://arduino.cc/it/Reference/AttachInterrupt        */
switch(pin) {
  case 2:
    return 0;
  case 3:
    return 1;
  case 21:
    return 2;
  case 20:
    return 3;
  case 19:
    return 4;
  case 18:
    return 5;   
  default:
    return -1;
  }
}


/* auxiliary debouncing function                             */
void debounce(int del) {
  int k;
  for (k=0;k<del;k++) {
    /* can't use delay in the ISR so need to waste some time
       perfoming operations, this uses roughly 0.1ms on uno  */
    k = k +0.0 +0.0 -0.0 +3.0 -3.0;
  }
}


/* Interrupt Service Routine: change on pin A for Encoder 0  */
void isrPinAEn0(){

  /* read pin B right away                                   */
  int drB = digitalRead(Enc[0].pinB);
  
  /* possibly wait before reading pin A, then read it        */
  debounce(Enc[0].del);
  int drA = digitalRead(Enc[0].pinA);

  /* this updates the counter                                */
  if (drA == HIGH) {   /* low->high on A? */
      
    if (drB == LOW) {  /* check pin B */
  	Enc[0].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[0].pos--;  /* going counterclockwise: decrement  */
    }
    
  } else {                       /* must be high to low on A */
  
    if (drB == HIGH) { /* check pin B */
  	Enc[0].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[0].pos--;  /* going counterclockwise: decrement  */
    }
    
  } /* end counter update                                    */

} /* end ISR pin A Encoder 0                                 */


/* Interrupt Service Routine: change on pin B for Encoder 0  */
void isrPinBEn0(){ 

  /* read pin A right away                                   */
  int drA = digitalRead(Enc[0].pinA);
  
  /* possibly wait before reading pin B, then read it        */
  debounce(Enc[0].del);
  int drB = digitalRead(Enc[0].pinB);

  /* this updates the counter                                */
  if (drB == HIGH) {   /* low->high on B? */
  
    if (drA == HIGH) { /* check pin A */
  	Enc[0].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[0].pos--;  /* going counterclockwise: decrement  */
    }
  
  } else {                       /* must be high to low on B */
  
    if (drA == LOW) {  /* check pin A */
  	Enc[0].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[0].pos--;  /* going counterclockwise: decrement  */
    }
    
  } /* end counter update */

} /* end ISR pin B Encoder 0  */


/* Interrupt Service Routine: change on pin A for Encoder 1  */
void isrPinAEn1(){

  /* read pin B right away                                   */
  int drB = digitalRead(Enc[1].pinB);
  
  /* possibly wait before reading pin A, then read it        */
  debounce(Enc[1].del);
  int drA = digitalRead(Enc[1].pinA);

  /* this updates the counter                                */
  if (drA == HIGH) {   /* low->high on A? */
      
    if (drB == LOW) {  /* check pin B */
  	Enc[1].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[1].pos--;  /* going counterclockwise: decrement  */
    }
    
  } else { /* must be high to low on A                       */
  
    if (drB == HIGH) { /* check pin B */
  	Enc[1].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[1].pos--;  /* going counterclockwise: decrement  */
    }
    
  } /* end counter update                                    */

} /* end ISR pin A Encoder 1                                 */


/* Interrupt Service Routine: change on pin B for Encoder 1  */
void isrPinBEn1(){ 

  /* read pin A right away                                   */
  int drA = digitalRead(Enc[1].pinA);
  
  /* possibly wait before reading pin B, then read it        */
  debounce(Enc[1].del);
  int drB = digitalRead(Enc[1].pinB);

  /* this updates the counter                                */
  if (drB == HIGH) {   /* low->high on B? */
  
    if (drA == HIGH) { /* check pin A */
  	Enc[1].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[1].pos--;  /* going counterclockwise: decrement  */
    }
  
  } else { /* must be high to low on B                       */
  
    if (drA == LOW) {  /* check pin A */
  	Enc[1].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[1].pos--;  /* going counterclockwise: decrement  */
    }
    
  } /* end counter update                                    */

} /* end ISR pin B Encoder 1                                 */


/* Interrupt Service Routine: change on pin A for Encoder 2  */
void isrPinAEn2(){

  /* read pin B right away                                   */
  int drB = digitalRead(Enc[2].pinB);
  
  /* possibly wait before reading pin A, then read it        */
  debounce(Enc[2].del);
  int drA = digitalRead(Enc[2].pinA);

  /* this updates the counter                                */
  if (drA == HIGH) {   /* low->high on A? */
      
    if (drB == LOW) {  /* check pin B */
  	Enc[2].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[2].pos--;  /* going counterclockwise: decrement  */
    }
    
  } else { /* must be high to low on A                       */
  
    if (drB == HIGH) { /* check pin B */
  	Enc[2].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[2].pos--;  /* going counterclockwise: decrement  */
    }
    
  } /* end counter update                                    */

} /* end ISR pin A Encoder 2                                 */


/* Interrupt Service Routine: change on pin B for Encoder 2  */
void isrPinBEn2(){ 

  /* read pin A right away                                   */
  int drA = digitalRead(Enc[2].pinA);
  
  /* possibly wait before reading pin B, then read it        */
  debounce(Enc[2].del);
  int drB = digitalRead(Enc[2].pinB);

  /* this updates the counter                                */
  if (drB == HIGH) {   /* low->high on B? */
  
    if (drA == HIGH) { /* check pin A */
  	Enc[2].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[2].pos--;  /* going counterclockwise: decrement  */
    }
  
  } else { /* must be high to low on B                       */
  
    if (drA == LOW) {  /* check pin A */
  	Enc[2].pos++;  /* going clockwise: increment         */
    } else {
  	Enc[2].pos--;  /* going counterclockwise: decrement  */
    }
    
  } /* end counter update                                    */

} /* end ISR pin B Encoder 2                                 */
