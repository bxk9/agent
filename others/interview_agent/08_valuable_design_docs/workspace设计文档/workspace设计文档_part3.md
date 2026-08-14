          "description": "需要精读的绝对路径",
          "type": "string"
        },
        "thumbnail_size": {
          "description": "返回的缩略图大小，可选\"small\"、\"medium\"、\"large\"\nsmall约64token\nmedium约256token\nlarge约1024token\n默认值：small",
          "type": "string"
        },
        "offset": {
          "description": "分页的起始位置，基于 bbpe155k tokenizer 结果按字符数比例估算（估算规则：中文 1 token ≈ 1.7 字符，英文 1 token ≈ 4 字符）。\n默认值 0",
          "type": "number"
        },
        "limit": {
          "description": "单页返回内容的最大长度，估算逻辑同offset\n默认值 4000",
          "type": "number"
        }
      },
      "required": ["path"]
    }
  }]
```

### 9.3 Code Execution Tools Schema

```json
[
  {
    "name": "CodeExecute",
    "description": "在有状态的执行环境中运行代码片段，支持富输出（图表、DataFrame等）。同一会话内多次调用共享变量上下文，类似 Jupyter Notebook。",
    "parameters": {
      "type": "object",
      "properties": {
        "language": {
          "type": "string",
          "description": "执行语言，支持 python、javascript、bash",
          "enum": ["python", "javascript", "bash"],
          "default": "python"
        },
        "code": {
          "type": "string",
          "description": "要执行的代码片段"
        },
        "timeout": {
          "type": "number",
          "description": "执行超时时间（秒），默认 30，最大 300",
          "default": 30
        }
      },
      "required": ["code"]
    }
  }
]
```

### 9.4 Browser Tools Schema

```json
[
  {
    "name": "click",
    "description": "Mouse left single click action.",
    "parameters": {
      "type": "object",
      "properties": {
        "point": {
          "type": "string",
          "description": "Click coordinates. The format is: <point>x y</point>"
        }
      },
      "required": ["point"]
    }
  },
  {
    "name": "left_double",
    "description": "Mouse left double click action.",
    "parameters": {
      "type": "object",
      "properties": {
        "point": {
          "type": "string",
          "description": "Click coordinates. The format is: <point>x y</point>"
        }
      },
      "required": ["point"]
    }
  },
  {
    "name": "right_single",
    "description": "Mouse right single click action.",
    "parameters": {
      "type": "object",
      "properties": {
        "point": {
          "type": "string",
          "description": "Click coordinates. The format is: <point>x y</point>"
        }
      },
      "required": ["point"]
    }
  },
  {
    "name": "drag",
    "description": "Mouse left button drag action.",
    "parameters": {
      "type": "object",
      "properties": {
        "start_point": {
          "type": "string",
          "description": "Drag start point. The format is: <point>x y</point>"
        },
        "end_point": {
          "type": "string",
          "description": "Drag end point. The format is: <point>x y</point>"
        }
      },
      "required": ["start_point", "end_point"]
    }
  },
  {
    "name": "scroll",
    "description": "Scroll action.",
    "parameters": {
      "type": "object",
      "properties": {
        "point": {
          "type": "string",
          "description": "Scroll start position. If not specified, default to execute on the current mouse position. The format is: <point>x y</point>"
        },
        "direction": {
          "type": "string",
          "description": "Scroll direction.",
          "enum": ["up", "down", "left", "right"]
        }
      },
      "required": ["direction"]
    }
  },
  {
    "name": "move_to",
    "description": "Mouse move action.",
    "parameters": {
      "type": "object",
      "properties": {
        "point": {
          "type": "string",
          "description": "Target coordinates. The format is: <point>x y</point>"
        }
      },
      "required": ["point"]
    }
  },
  {
    "name": "mouse_down",
    "description": "Mouse down action.",
    "parameters": {
      "type": "object",
      "properties": {
        "point": {
          "type": "string",
          "description": "Mouse down position. If not specified, default to execute on the current mouse position. The format is: <point>x y</point>"
        },
        "button": {
          "type": "string",
          "description": "Down button. Default to left.",
          "enum": ["left", "right"]
        }
      }
    }
  },
  {
    "name": "mouse_up",
    "description": "Mouse up action.",
    "parameters": {
      "type": "object",
      "properties": {
        "point": {
          "type": "string",
          "description": "Mouse up position. If not specified, default to execute on the current mouse position. The format is: <point>x y</point>"
        },
        "button": {
          "type": "string",
          "description": "Up button. Default to left.",
          "enum": ["left", "right"]
        }
      }
    }
  },
  {
    "name": "type",
    "description": "Type content.",
    "parameters": {
      "type": "object",
      "properties": {
        "content": {
          "type": "string",
          "description": "Type content. If you want to submit your input, use \\n at the end of content."
        }
      },
      "required": ["content"]
    }
  },
  {
    "name": "hotkey",
    "description": "Press hotkey.",
    "parameters": {
      "type": "object",
      "properties": {
        "key": {
          "type": "string",
          "description": "Hotkeys you want to press. Split keys with a space and use lowercase."
        }
      },
      "required": ["key"]
    }
  },
  {
    "name": "press",
    "description": "Press key.",
    "parameters": {
      "type": "object",
      "properties": {
        "key": {
          "type": "string",
          "description": "Key you want to press. Only one key can be pressed at one time."
        }
      },
      "required": ["key"]
    }
  },
  {
    "name": "release",
    "description": "Release key.",
    "parameters": {
      "type": "object",
      "properties": {
        "key": {
          "type": "string",
          "description": "Key you want to release. Only one key can be released at one time."
        }
      },
      "required": ["key"]
    }
  },
  {
    "name": "wait",
    "description": "Wait for a while.",
    "parameters": {
      "type": "object",
      "properties": {
        "time": {
          "type": "integer",
          "description": "Wait time in seconds."
        }
      }
    }
  },
  {
    "name": "take_screenshot",
    "description": "Take screenshot.",
    "parameters": {
      "type": "object",
      "properties": {}
    }
  },
  {
    "name": "open_url_in_browser",
    "description": "Opens a specified URL or local file in a GUI-based browser and returns a screenshot after loading.",
    "parameters": {
      "type": "object",
      "properties": {
        "url": {
          "type": "string",
          "description": "The URL or local file path to open. Must be a valid HTTP/HTTPS URL or a local file path."
        }
      },
      "required": ["url"]
    }
  },
  {
    "name": "AskHumanToControlBrowser",
    "description": "请求用户接管浏览器进行操作，例如：当遇到必须要用户登录的时候，或者需要输入验证码的时候等等。Returns: - STDOUT (str): 接管是否成功的信息。比如‘用户已完成接管，请继续下一步’或‘用户未完成接管，请继续下一步’",
    "parameters": {
      "type": "object",
      "properties": {
        "display_message": {
          "type": "string",
          "description": "请求用户接管浏览器时，展示给用户的信息，例如：当需要用户的操作是登录时，可以提示“该网站需要登录才能访问，请手动操作完成登录。"
        }
      },
      "required": ["display_message"]
    }
  }
]
```

### 9.5 调研文档

[https://docs.vivo.xyz/s/rtTacrDk](https://docs.vivo.xyz/s/rtTacrDk) 邀请您加入文档协作【豆包超能模式 Workspace Sandbox 运行时分析文档】