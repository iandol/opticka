%
%PAL_PFML_setupParameterizationStruct      Creates a parameter 
%   reparameterization structure for (optional) use in functions which 
%   allow specification of a model regarding the parameters of PFs across 
%   several datasets.
%
%Alternative spelling (PAL_PFML_setupParametrizationStruct) works also.
%
%Syntax: funcParams = PAL_PFML_setupParameterizationStruct;
%
%funcParams is a structure with the fields: 
%   '.funcA'            %function handle to function reparameterizing
%                       %thresholds.
%   '.paramsValuesA'    %parameter values for threshold reparameterization
%                       %function.
%   '.paramsFreeA'      %vector containing '1's for free threshold 
%                       %parameters, '0's for fixed parameters.
%Similar fields exist for slopes ('.funcB', etc.), guess-rates ('.funcG',
%etc.), and lapse-rates ('.funcL', etc.). User should assign appropriate
%values to fields in order to effect a custom parameterization of
%parameters. Type: 'help PAL_PFML_CustomDefine' for more information on how
%to do so.
%
%Introduced: Palamedes version 1.8.1 (NP)

function funcParams = PAL_PFML_setupParameterizationStruct

    funcParams.funcA = [];
    funcParams.paramsValuesA = [];
    funcParams.paramsFreeA = [];
    funcParams.funcB = [];
    funcParams.paramsValuesB = [];
    funcParams.paramsFreeB = [];
    funcParams.funcG = [];
    funcParams.paramsValuesG = [];
    funcParams.paramsFreeG = [];
    funcParams.funcL = [];
    funcParams.paramsValuesL = [];
    funcParams.paramsFreeL = [];