# Parametersets
This folder contains the parameterset to be added.

## Contributing guidelines
Parametersets MUST be specified as XML files, starting with "parameters_". Their structure MUST follow that of the [main parameterset] (https://github.com/reprostat/reproanalysis/blob/master/parametersets/parameters_defaults.xml).
Settings already specified in the main parameterset or in other extensions SHOULD NOT be replicated without a good reason to overwrite them. Then, user SHOULD also be informed that the this extension MUST be loaded later.

Back-end functions should be placed in subfolders. See https://github.com/reprostat/reproanalysis for an example layout.