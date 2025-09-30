# Contributing

Contributions are welcome and encouraged.

## Formatting

The preferred tool for formatting files is [qmlfmt](https://github.com/jesperhh/qmlfmt) (also available on aur as qmlfmt-git). It actually kinda sucks, but `qmlformat` doesn't work with null safe operators and ternarys and pragma statements and a bunch of other things that are supported.

We need some consistent style, so this at least gives the same formatter that Qt Creator uses.

You can configure it to format on save in vscode by configuring the "custom local formatters" extension then adding this to settings json.

```json
  "customLocalFormatters.formatters": [
    {
      "command": "sh -c \"qmlfmt -t 4 -i 4 -b 250 | sed 's/pragma ComponentBehavior$/pragma ComponentBehavior: Bound/g'\"",
      "languages": ["qml"]
    }
  ],
  "[qml]": {
    "editor.defaultFormatter": "jkillian.custom-local-formatters",
    "editor.formatOnSave": true
  },
```

Sometimes it just breaks code though. Like turning `"_\""` into `"_""`, so you may not want to do formatOnSave.

## Pull request

Include screenshots/video if applicable in your pull request if applicable, to visualize what your change is affecting.
