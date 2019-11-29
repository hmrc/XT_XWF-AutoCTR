# XWF Auto CTR (An X-Tension to Automate Extraction of Common File Types to a Container)

###  *** Requirements ***
  This X-Tension is designed for use only with X-Ways Forensics
  This X-Tension is designed for use only with v16.5 or later.
  This X-Tension is not designed for use on Linux or OSX platforms.
  There is a compiled 32 and 64 bit version of the X-Tension to be used with the
  corresponding version of X-Ways Forensics.

###  *** Usage Disclaimer ***
  This X-Tension is a Proof-Of-Concept Alpha level prototype, and is not finished.
  It has known limitations. You are NOT advised to use it, yet, for any evidential
  work for criminal courts.

###  *** Functionality Overview ***
  The X-Tension helps automate and speed up the process of extracting specified
  files that match certain pre-defined categories to an XWF evidence container.
  See function PrepareFileTypeList for the files currently extracted.

  The purpose of the X-Tension is for teams who want to use a very fast and in-depth
  forensic tool to do the bulk of the initial work (process a forensic image), 
  with a view to then passing the more straight forward files to other
  tools with different capabilities, such as OCR, e-discovery tools etc. By working this way, should
  further forensic work be required, the X-Ways Forensics case can simply be
  re-opened without further pre-processing stages being required.
  In addition, investigation teams are able to use capabilities of other platforms 
  to further their investigations without delay.

  It should be executed via the "Refine Volume Snapshot" (RVS, F10) of X-Ways Forensics

  On completion the resulting evidence container will be named after the
  evidence object from which the data came.

  The output is saved to the users "Documents" folder automatically for now,
  e.g. C:\Users\Joe\Documents. Future fix will allow alternative user specified locations.

###  TODOs
   // TODO Ted Smith :
     Write user manual
     Allow output to be redirected to users choice
     Apply version check

  *** License ***
  This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html")
  and The Open Government Licence (OGL) v3.0.
  (http://www.nationalarchives.gov.uk/doc/open-government-licence and
  http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

###  *** Collaboration ***
  Collaboration is welcomed, particularly from Delphi or Freepascal developers.
  This version was created using the Lazarus IDE v2.0.4 and Freepascal v3.0.4.
  (www.lazarus-ide.org)