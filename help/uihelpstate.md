---
document-css: true
header-includes:
    - |
        <style>
            html {font-family: Avenir Next,Avenir,Gill Sans,Helvetica,sans-serif;}
            body {padding: 0px 50px;}
            p {text-align: justify;}
            pre {font-family: consolas, menlo, monospace; line-height: 0.6em !important; background-color: #F0F0F0}
            pre code {font-size: 0.6em !important; white-space: pre}
        </style>
---

# State Info Files

For behavioural tasks, opticka uses `StateInfo.m` files that are loaded below and are used to specify the StateMachine structure. For example the `DefaultStateInfo.m` file defines several states and how the task switches between them:

```
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

State info files must be edited in the MATLAB editor. You can use the class object methods from the screen manager [`s`], state machine [`sM`], task sequence [`task`], stimulus list [`stims`], eyetracker [`eT`], digital I/O [`io`].




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