---
toc: false
---

# Adding User Functions

For behavioural tasks, [state-machine files](uihelpstate.html) specify the experiment states and functions that run on `enter`/`within`/`transition` and `exit` of *each* state. Most functions are specified by the built-in classes like `screenManager`, `taskSequence` etc. **_BUT_** a user can add functions and store information using a `userFunctions.m` file.

You use <kbd>Load Functions File…</kbd> to load this file; this will be used when you run your task. You can also use the <kbd>Edit Functions File…</kbd> button to open it in the MATLAB editor.

## How to Use these Functions

Lets add a new function:

```matlab
function drawSomething(me)
	% use screenManager (me.s) to draw some text to the PTB screen
	me.s.drawText('Hello from UserFunctions')
end
```

**Remember**: `me` refers to itself, in this case `userFunctions`. So `me.s` refers to the `s` property which is set as a handle to `screenManager`.

Now lets say we want to run this function during the `fixate` state (on every frame, so we use `withinFcn`); find the cell array of functions for this state in the `stateInfo.m` file you are using and add our new function to the cell array. Because cell arrays use `@()` function handles, so you will need to insert `@()drawSomething(uF)`:

```matlab
%--------------------fix within
fixFcn = {
	@()drawSomething(uF); % our new custom function from our uF object
	@()draw(stims); %draw stimuli
	@()drawPhotoDiode(s,[0 0 0]); % black square for photodiode
	@()animate(stims); % animate stimuli for subsequent draw
};
```

This will now run where the `fixFcn` array is, in this case we can see that is `fixate` > `withinFcn`:

```matlab
stateInfoTmp = {
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'fixate'	'incorrect'	10		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
}
```

### Using Variables (Properties)

When using `@()` function handles, you cannot change class variables (properties) directly. Instead you can use functions that set the properties. Examples of these kinds of functions from the core classes are `show(stims, 3)`. To see how we do this with our customised userFunctions, lets add a new property to our custom `userFunctions.m` file:

```matlab
	properties % ADD YOUR OWN VARIABLES HERE
		myToggle = false
	end
```

…and then make a new function to set this property:

```matlab
	% Add your functions here!

	function doToggle(me,value)
		me.myToggle = value;
	end
```

You can now add this function in your state file: `@()doToggle(uF, true)`.

This should allow you to add many custom functions, and store information in variables without needing to edit any of the core opticka classes. If you think you need something more advanced then you can open an issue on github to add functions to the core classes or add a new dedicated class.


