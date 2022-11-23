---
toc: true
---

# StateMachine Info Files

Any experiment can be thought of as a series of states (delay, fixating, stimulation, reward) and transitions between them. State Machines are a widely used control system for these types of scenarios. The important definition is: 

1. a state machine can be in exactly one of a finite number of states at any given time. 
1. The state machine can change from one state to another in response to some inputs; the change from one state to another is called a **transition**. A MATLAB function controls the transition, where it can return a state name that forces a transition to that state.
1. MATLAB functions can run when we **enter**, are **within**, or **exit** a state.
1. An FSM is defined by a *table* of its states, its initial state, and the inputs that trigger each transition

Opticka uses a state-machine specified by `StateInfo.m` files that controls *which* functions run when we **enter**, are **within**, when we **exit**, and **transition** experiment states. See below for the core functions that can run at any point; you can write your own functions and store data in a [userFunctions.m](uihelpfunctions.html) file.

For example the `DefaultStateInfo.m` file defines several experimental states (*prefix*, *fixate*, *stimulus*, *incorrect*, *breakfix*, *correct*, *timeout*) and how the task switches between them (either with a timer or transitioned using an eyetracker to check fixation):

```{.smaller}
                                                       ┌───────────────────┐
                                                       │      prefix       │
  ┌──────────────────────────────────────────────────▶ │    hide(stims)    │ ◀┐
  │                                                    └───────────────────┘  │
  │                                                      │                    │
  │                                                      ▼                    │
  │                         ┌───────────┐  inFixFcn:   ┌───────────────────┐  │
  │                         │ incorrect │  incorrect   │      fixate       │  │
  │                         │           │ ◀─────────── │   show(stims,2)   │  │
  │ reward!                 └───────────┘              └───────────────────┘  │
  │                           │                          │ inFixFcn:          │
  │                           │                          │ stimulus           │
  │                           │                          ▼                    │
┌─────────┐  maintainFixFcn:  │                        ┌───────────────────┐  │
│ correct │  correct          │                        │     stimulus      │  │
│         │ ◀─────────────────┼─────────────────────── │ show(stims,[1 2]) │  │
└─────────┘                   │                        └───────────────────┘  │
                              │                          │ maintainFixFcn:    │
                              │                          │ breakfix           │
                              │                          ▼                    │
                              │                        ┌───────────────────┐  │
                              │                        │     breakfix      │  │
                              │                        └───────────────────┘  │
                              │                          │                    │
                              │                          ▼                    │
                              │                        ┌───────────────────┐  │
                              │                        │      timeout      │  │
                              └──────────────────────▶ │      tS.tOut      │ ─┘
                                                       └───────────────────┘
```

State info files, being plain `.m` files, should be edited in the MATLAB editor (the GUI has an edit button that opens the file in the editor for you). You can use the class methods for the screen manager (`s`), state machine (`sM`), task sequence (`task`), stimulus list (`stims`), eyetracker (`eT`), digital I/O (`io`) etc. You can also add custom functions to a [userFunctions](uihelpfunctions.html) file. The most important built-in methods are shown below…

----------------------------------------------

```{.include}
/Users/ian/Code/opticka/help/METHODS.md
```

<!--
digraph{
    prefix[label="prefix\nhide(stims)"];
    fixate[label="fixate\nshow(stims,2)"];
    stimulus[label="stimulus\nshow(stims,[1 2])"];
    prefix -> fixate;
    fixate -> stimulus[label="inFixFcn:\nstimulus"];
    fixate -> incorrect[label="inFixFcn:\nincorrect"];
    stimulus -> correct[label="maintainFixFcn:\ncorrect"];
    stimulus -> breakfix[label="maintainFixFcn:\nbreakfix"];;
    correct -> prefix [label="rewarded"];
    breakfix -> timeout;
    incorrect -> timeout;
    timeout -> prefix;
} -->