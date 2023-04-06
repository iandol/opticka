---
toc: true
---

# State Machine Info Files

Any experiment can be thought of as a series of states (delay, fixate, stimulus, reward, timeout e.t.c.) and transitions between these states. State Machines are a widely used control system for these types of scenarios. The important definition of a state machine is: 

1. The state machine must be in exactly one of a finite number of states at any given time. States usually run for a defined amount of time.
1. The state machine can also change from one state to another in response to some input; the change from one state to another is called a **transition** (`transitionFcn`). A function controls the transition, returning a different state name that forces a transition to this new state.
1. Functions can run when we **enter** (`enterFcn`), are **within** (`withinFcn`), or **exit** (`exitFcn`) a state.

Opticka defines all of this in a `StateInfo.m` file that specifies function arrays and then assigns them to a state list. The Opticka GUI visualises the state table and shows each function array. 

For example this cell array identifies two functions which draw and animate our `stims` stimulus object:

```matlab
{ @()draw(stims); @()animate(stims); }
```

See details below for the core functions that can run during the state machine traversal. You can additionally write your own functions and store them in a [userFunctions.m](uihelpfunctions.html) class file.

For example the `DefaultStateInfo.m` file defines several experiment states (*prefix*, *fixate*, *stimulus*, *incorrect*, *breakfix*, *correct*, *timeout*) and how the task switches between them (either with a timer or transitioned using an eyetracker):

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

State info files, being plain `.m` files, should be edited in the MATLAB editor (the GUI has an edit button that opens the file in the editor for you).  

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