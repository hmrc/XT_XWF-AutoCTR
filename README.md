# XWF Auto CTR (An X-Tension to Automate Extraction of Common File Types to a Container)
   Most recently tested on : v20.0 (Sept 2020)

###  *** Requirements ***
  This X-Tension is designed for use only with X-Ways Forensics, x64 edition
  This X-Tension is designed for use only with v18.9 of X-Ways Forensics or later (for now).
  This X-Tension is not designed for use on Linux or OSX platforms.

###  *** Usage Disclaimer ***
  This X-Tension is a Proof-Of-Concept Alpha level prototype, and is not finished.
  It has known limitations. You are NOT advised to use it, yet, for any evidential
  work for criminal courts.

###  *** Functionality Overview ***
  The X-Tension helps automate and speed up the process of extracting specified
  files that match certain pre-defined categories to an XWF evidence container.
  See function PrepareFileTypeList for the files currently extracted.

  Note it uses the "Type Description" of XWF to classify file types.
  Not the 'Type' or 'Category' classifications.

  The purpose of the X-Tension is for teams who want to use a very fast and in-depth
  forensic tool to do the bulk of the hard work (process a forensic image fully)
  initially, with a view to then passing the more straight forward files to other
  tools with different capabilities, such as e-discovery tools. By working this way, should
  further forensic work be required, the X-Ways Forensics case can simply be
  re-opened without further pre-processing stages being required and the required
  information can be obtained immediately. In addition, investigation teams are
  able to use capabilities of other platforms to further their investigations without
  delay

  It should be executed via the "Refine Volume Snapshot" (RVS, F10) of X-Ways Forensics

  On completion the resulting evidence container will be named after the
  evidence object from which the data came.

  The output is saved to the users "Documents" folder automatically for now,
  e.g. C:\Users\Joe\Documents. Future fix will allow alternative user specified locations.

###  TODOs
   // TODO Ted Smith :
     Write user manual

  *** License ***
  This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html")
  and The Open Government Licence (OGL) v3.0.
  (http://www.nationalarchives.gov.uk/doc/open-government-licence and
  http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

###  *** Collaboration ***
  Collaboration is welcomed, particularly from Delphi or Freepascal developers.
  This version was created using the Lazarus IDE v2.0.10 and Freepascal v3.2.0.
  (www.lazarus-ide.org)