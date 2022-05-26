# mscl-mode

Package mscl-mode provides a major mode for editing MSCL code in GNU Emacs.
Features include syntax highlighting and indentation, as well as support for
auto-numbering and renumering of code lines.


## Installation

To install manually, place mscl-mode.el in your load-path, and add the
following lines of code to your init file:

```elisp
(autoload 'mscl-mode "mscl-mode" "Major mode for editing MSCL code." t)
(add-to-list 'auto-mode-alist '("\\.pwx?macro\\'" . mscl-mode))
```


## Usage


### Formatting Code

TAB indents the current line of MSCL code, including line numbers if available.
If the region is active, TAB indents all lines in the region.

_C-c C-f_ formats the entire buffer; indents all lines, and removes any extra
whitespace. If the region is active, _C-c C-f_ formats all lines in the region.


### Navigation

Package mscl-mode also provides additional functionality to navigate in the
source code. _M-._ will find and move to the line number, label, or variable at
point, and _M-,_ will move back again. For more information, see function
xref-find-definitions.


## Configuration

The following table lists the customizable variables that affect mscl-mode
in some way:

<table>
  <tr>
    <th align="left">Name</th>
    <th align="left">Description</th>
    <th align="left">Default Value</th>
  </tr>
  <tr>
    <td>mscl-delete-trailing-whitespace</td>
    <td>If non-nil, mscl-format-code deletes trailing whitespace while formatting.</td>
    <td>nil</td>
  </tr>
  <tr bgcolor="#EEEEFF">
    <td>mscl-indent-offset</td>
    <td>The number of columns to indent code blocks, for example inside an IF statement.</td>
    <td>4</td>
  </tr>
  <tr bgcolor="#EEEEFF">
    <td>mscl-mode-hook</td>
    <td>Hook run when entering MSCL mode.</td>
    <td>nil</td>
  </tr>
  <tr>
    <td>delete-trailing-lines (simple.el)</td>
    <td>If non-nil, mscl-format-code deletes trailing empty lines while formatting.</td>
    <td>t</td>
  </tr>
</table>


