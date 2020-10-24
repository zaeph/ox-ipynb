[![License GPL 3][badge-license]](http://www.gnu.org/licenses/gpl-3.0.txt)

Synopsis
---------------

> **NOTE:** This repository is a WIP.  The software is still
> a prototype, but it is functional.

`ox-ipynb` is an [`org-mode`](https://orgmode.org/) exporter for
[Jupyter Notebook](https://jupyter.org/).  It is written and designed
with the intention of making it an official org-mode exporter, i.e., by
merging it upstream.  As such, when a stable version is achieved,
a request for an upstream merge will be issued.

Preview
---------------

> **NOTE:** This section will contain screenshots/screencasts when they
> are ready.

Installation
---------------

### Via MELPA

The package is not yet available on
[MELPA](https://github.com/melpa/melpa).

### Via cloning

You can clone the repository somewhere in your `load-path`.  If you
would like to assist with development, this is the way to go.

To do that:
1. Create a directory where you’d like to clone the repository,
   e.g. `mkdir ~/projects`.
2. `cd ~/projects`
3. `git clone https://github.com/zaeph/ox-ipynb.git`

You now have the repository cloned in `~/projects/ox-ipynb/`.
See [Quick-start](#quick-start-) to learn how to add it to your
`load-path` and to get started with the package.

You can also copy
[`ox-ipynb.el`](https://github.com/zaeph/ox-ipynb/blob/master/ox-ipynb.el)
somewhere where `load-path` can access it, but you’d have to update the
file manually.

Quick-start 🚀
---------------

You can get `ox-ipynb` up and running by pasting the following sexps in
your
[init-file](https://www.gnu.org/software/emacs/manual/html_node/emacs/Init-File.html):

### With `use-package`

```el
(use-package ox-ipynb
  :load-path "~/projects/org-roam-bibtex/") ;Modify with your own path
```

### Without `use-package`

```el
(add-to-list 'load-path "~/projects/ox-ipynb/") ;Modify with your own path
(require 'ox-ipynb)
```

Usage
---------------

You can now access the Jupyter exporter in an `org-mode` file by
pressing `C-c C-e`.  You will see a line `[j] Export to Jupyter` in the
`*Org Export Dispatcher*` which mentions the different options available
to you.

Frequently-Asked Questions
---------------

**Q**: How does this package differ from [`jkitchin/ox-ipynb`](https://github.com/jkitchin/ox-ipynb)?

**A**: `jkitchin/ox-ipynb` is a another attempt at a Jupyter Notebook
exporter for `org-mode`, and a great one at that.  It covers more
edge-cases than `zaeph/ox-ipynb` currently does, but it suffers from
early design decisions which 1) make it nearly impossible to implement
some common `org-export` features, and 2) make it impossible to merge it
upstream.  `zaeph/ox-ipynb` was designed from the ground up with an
upstream merge in mind, most notably by playing nice with
[`ox.el`](https://orgmode.org/worg/dev/org-export-reference.html) and
[`org-element.el`](https://orgmode.org/worg/dev/org-element-api.html),
which has the added benefit of making a lot of things Just Work™.

Contributing
---------------

To report bugs and suggest new feature use the issue tracker.  If you
have some code which you would like to be merged, then open a pull
request.

License
---------------

Copyright © Leo Vivier and contributors. Distributed under the GNU
General Public License, Version 3.

[badge-license]: https://img.shields.io/badge/license-GPL_3-green.svg
