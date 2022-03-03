---
document-css: true
header-includes:
    - |
       <style>
            html {font-family: Avenir Next,Avenir,Gill Sans,Helvetica,sans-serif;}
            body {padding: 0px 50px;}
            p {text-align: justify;}
            pre {font-family: consolas, menlo, monospace; line-height: 0.8em !important; background-color: #F0F0F0}
            pre code {font-size: 0.8em !important; white-space: pre}
            kbd {font-size: 0.8em;margin: 0px 0.1em;padding: 0.1em 0.1em;border-radius: 3px;border: 1px solid rgb(204, 204, 204);display: inline-block;box-shadow: 0px 1px 0px rgba(0,0,0,0.2), inset 0px 0px 0px 2px #ffffff;background-color: rgb(247, 247, 247);text-shadow: 0 1px 0 #fff}
        </style>
---

# Configuring Variables

Opticka uses the taskSequence class to specify one or more variable names and values [`nVar`] that can be randomised using blocked repetition and applied to stimuli during a task. The taskSequence class can also specify independent trial level [`trialVar`] and block level [`blockVar`] randomisation values. 

# Log or Linear interpolation

You can enter 3 values, `start | end | steps`, and press the <kbd>log</kbd> or the <kbd>lin</kbd> buttons to interpolate a log or linear range, for example `1 2 5` would get converted to `1 1.1892 1.4142 1.6818 2` when pressing the <kbd>log</kbd> button.

# Variable modifiers

Variables can have modifiers, best explained by example:

1. Name = `angle`
2. Values = `[-90 90]`
3. Affects = `1`
4. Modifier = `2; 90`

In this case, angle is varied -90 and 90 for stimulus 1. Stimulus 2 has the modifier +90 applied, so for example is stimulus 1 = `-90°` then stimulus 2 = `-90° + 90 = 0°`.

