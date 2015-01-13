## ObjectGraph
ObjectGraph can show oriented graph of dependencies between classes in your project.
This plugin is based on [objc_dep](https://github.com/nst/objc_dep) and [Graphviz](http://www.graphviz.org/).

![Screenshot](https://raw.githubusercontent.com/vampirewalk/ObjectGraph-Xcode/master/ScreenShot.png)

![Example](https://raw.githubusercontent.com/vampirewalk/ObjectGraph-Xcode/master/ObjectGraph.png)

Thanks to kattrali, I get inspiration and import some code from cocoapods-xcode-plugin.

## Install 
Install Graphviz
```
brew install graphviz
```

Clone and build the project, then restart Xcode.

## Uninstall
Run rm -r ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins/ObjectGraph.xcplugin/
