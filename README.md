# tiler.vim
Tiling window manger for Vim

## Features
  1. multiple layouts,
	2. can increase or decrease master window count on the fly,
	3. support for popups e.g. nerdtree, tagbar, quickfix, etc,
	4. each tab has its own settings

See the help file for more information.

# Install
Using vim-plug:

```
Plug 'zhamlin/tiler.vim'
```

# Commands

| Command              | List                                                                    |
| ---                  | ---                                                                     |
| `TilerFocus`         | Moves current window to master window                                   |
| `TileReorder`        | Creates the correct window layout                                       |
| `TileClose`          | Closes current window                                                   |
| `TileNew`            | Opens a new window                                                      |
| `TileOpen [FILE]`    | Opens a file in a new window                                            |
| `TileResize [SIZE]`  | Resizes master window to [SIZE]                                         |
| `TileSwitch [LAYOUT]`| Switches the current layout to [LAYOUT]                                 |
