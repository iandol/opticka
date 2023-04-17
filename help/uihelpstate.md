---
toc: true
---

# Controlling Behavioural Tasks using State Machines

Any experiment can be thought of as a series of states (delay period, initiate fixation, present stimulus, give subject feedback, post-trial timeout, etc.) and conditions for switching between these states. State Machines are a widely used control system for these types of scenarios. The important definition of a state machine is: 

1. The state machine must be in exactly one of a finite number of states at any given time. States  run for a defined amount of time by default before switching to a `next` state.
1. The state machine cal also change from one state to another based on rules; the conditional change from one state to another is called a **transition**. A function controls the transition (`transitionFcn`), returning a different state name that forces a transition to this new state.
1. Functions can run when we **enter** (`enterFcn`), are **within** (`withinFcn`), or **exit** (`exitFcn`) a state.

Opticka defines all of this in a `StateInfo.m` file that specifies function arrays and assigns them to a state list. The Opticka GUI visualises the state table and lists out each function array. 

For example this cell array identifies two functions which draw and animate our `stims` stimulus object. The `@()` identifies these as MATLAB function handles:

```matlab
{ @()draw(stims); @()animate(stims); }
```

Opticka has many core functions that can run during state machine traversal. You can additionally write your own functions and store them in a [userFunctions.m](uihelpfunctions.html) class file.  

As an example, the `DefaultStateInfo.m` file defines several experiment states (*prefix*, *fixate*, *stimulus*, *incorrect*, *breakfix*, *correct*, *timeout*) and how the task switches between them (either with a timer or transitioned using an eyetracker):

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