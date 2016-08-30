# Mapcode iOS Application

[![License](http://img.shields.io/badge/license-APACHE2-blue.svg)]()

**Copyright (C) 2014-2016 Stichting Mapcode Foundation (http://mapcode.com)**


### Usage

* Enter an address or coordinate to get a mapcode, or move the map around.

* Tap twice on the map to zoom in really deep.

* Enter a mapcode in the address field to show it on the map. Tip: if you omit
the territory for local mapcodes, the current territory is used.

* Tap the `>>` buttons to show next territory or mapcode.

* Tap the mapcode itself to copy it to the clipboard.

* Tap on the Maps icon to plan a route to it using the Maps app.

* Tap on the Share button to share the mapcode with any other app.

* Note that a single location can have mapcodes with different territory codes.
  The 'correct' territory is always included, but other territories may be presented as well.

* You can select the correct territory by tapping on the `>>` button.

For questions, or more info on mapcodes in general, please visit us at:
http://mapcode.com


### Privacy Notice

This app uses the Mapcode REST API at https://api.mapcode.com.
This free online service is provided for demonstration purposes
only and the Mapcode Foundation accepts no claims
on its availability or reliability, although we try hard to
provide a stable and decent service. Note that anonymized
usage and log data, including mapcodes and coordinates, may
be collected to improve the service and better anticipate
on its scalability needs. The collected data contains no IP
addresses, is processed securely in the EEA and is never
sold or used for commercial purposes.


# License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


# Using Git and `.gitignore`

It's good practice to set up a personal global `.gitignore` file on your machine which filters a number of files
on your file systems that you do not wish to submit to the Git repository. You can set up your own global
`~/.gitignore` file by executing:
`git config --global core.excludesfile ~/.gitignore`

In general, add the following file types to `~/.gitignore` (each entry should be on a separate line):
`*.com *.class *.dll *.exe *.o *.so *.log *.sql *.sqlite *.tlog *.epoch *.swp *.hprof *.hprof.index *.releaseBackup *~`

If you're using a Mac, filter:
`.DS_Store* Thumbs.db`

If you're using IntelliJ IDEA, filter:
`*.iml *.iws .idea/`

If you're using Eclips, filter:
`.classpath .project .settings .cache`

If you're using NetBeans, filter:
`nb-configuration.xml *.orig`

The local `.gitignore` file in the Git repository itself to reflect those file only that are produced by executing
regular compile, build or release commands, such as:
`target/ out/`


# Bug Reports and New Feature Requests

If you encounter any problems with this library, don't hesitate to use the `Issues` session to file your issues.
Normally, one of our developers should be able to comment on them and fix.
