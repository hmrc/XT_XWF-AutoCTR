library XWFAutoCTR;
{
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
  files that match certain pre-defined categories to an XWF evidence container saved
  to a location of the users choosing. See function PrepareFileTypeList for the files 
  currently extracted.

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

}
{$mode Delphi}{$H+}

uses
  Classes, XT_API, windows, sysutils, contnrs, md5, LazUTF8, lazutf8classes;

  const
    BufEvdNameLen=256;
var
  // These are global vars
  MainWnd                  : THandle;
  CurrentVolume            : THandle;
  hContainerFile           : THandle;
  slFileTypeList           : TStringList;
  TotalDataInBytes         : Int64;
  itemcount                : integer;

  infoflag_Error           : integer;
  infoflag_NotVerified     : integer;
  infoflag_TooSmall        : integer;
  infoflag_TotallyUnknown  : integer;
  infoflag_Confirmed       : integer;
  infoflag_NotConfirmed    : integer;
  infoflag_NewlyIdentified : integer;
  infoflag_MisMatch        : integer;

  // Evidence name is global for later filesave by name
  pBufEvdName              : array[0..BufEvdNameLen-1] of WideChar;
  // We want the output folder to be set only once, otherwise the user will be asked
  // repeatedly for the output path for every evidence object during RVS. Once set
  // we switch a flag to true so that the location is not asked for again
  OutputFolder             : Unicodestring;
  OutputFolderIsSpecified  : boolean = Default(Boolean);
  // To check release version of XWF for compatability
  VerRelease               : LongInt = Default(LongInt);
  ServiceRelease           : Byte    = Default(Byte);

// The first call needed by the X-Tension API. Must return 1 for the X-Tension to continue.
function XT_Init(nVersion, nFlags: DWord; hMainWnd: THandle; lpReserved: Pointer): LongInt; stdcall; export;
begin
  // Get high 2 bytes from nVersion
  VerRelease := Hi(nVersion);
  // Get 3rd high byte for service release. We dont need it yet but we might one day
  ServiceRelease := HiByte(nVersion);

  if VerRelease < 1890 then
  begin
     MessageBox(MainWnd, 'Error: ' +
                        ' Please execute this X-Tension using v18.9 or above ',
                        'XWF Auto Container Generator', MB_ICONINFORMATION);
    result := -1;  // Should abort and not run any further
  end
  else
    begin
      result := 1;  // Continue, with no need for warning
      // Just make sure everything is hunkydory and set to zero
      itemcount                := 0;
      TotalDataInBytes         := 0;
      infoflag_Error           := 0;
      infoflag_NotVerified     := 0;
      infoflag_TooSmall        := 0;
      infoflag_TotallyUnknown  := 0;
      infoflag_Confirmed       := 0;
      infoflag_NotConfirmed    := 0;
      infoflag_NewlyIdentified := 0;
      infoflag_MisMatch        := 0;
      hContainerFile           := -1;
      OutputFolder             := '';   // Set this to empty to start with
      FillChar(pBufEvdName, SizeOf(pBufEvdName), $00);
      // Check XWF is ready to go. 1 is normal mode, 2 is thread-safe. Using 1 for now
      if Assigned(XWF_OutputMessage) then
      begin
        Result := 1; // lets go
        MainWnd:= hMainWnd;
      end
      else Result := -1; // stop
    end;
end;

// Used by the button in the X-Tension dialog to tell the user about the X-Tension
// Must return 0
function XT_About(hMainWnd : THandle; lpReserved : Pointer) : Longword; stdcall; export;
begin
  result := 0;
  MessageBox(MainWnd,  ' XWF Auto CTR X-Tension for X-Ways Forensics. ' +
                       ' To be executed only via the RVS dialog of XWF v16.5 or higher. ' +
                       ' Developed by Ted Smith. Released under the OGL (Open Government License)' +
                       ' Intended use : to automate extraction of common file types to an evidence container.'
                      ,'XWF Auto CTR', MB_ICONINFORMATION);
end;
// GetOutputLocation : Gets the output location; i.e. where to put the container
// Returns empty string on failure
function GetOutputLocation() : widestring; stdcall; export;
const
  BufLen=2048;
var
  Buf, outputmessage : array[0..Buflen-1] of WideChar;
  UsersSpecifiedPath : array[0..Buflen-1] of WideChar;
  UserInputResultVal : Int64 = Default(Int64);
  OutputOK           : Boolean = Default(Boolean);
begin
  result              := Default(widestring);
  outputmessage := '';
  FillChar(outputmessage, Length(outputmessage), $00);
  FillChar(UsersSpecifiedPath, Length(UsersSpecifiedPath), $00);
  FillChar(Buf, Length(Buf), $00);

  // Set default output location
  UsersSpecifiedPath := 'C:\temp\';

  // Ask XWF to ask the user if s\he wants to override that default location
  UserInputResultVal := XWF_GetUserInput('Save container to folder...', @UsersSpecifiedPath, Length(UsersSpecifiedPath), $00000002);
  // If output location exists, use it, otherwise, create it
  if DirectoryExists(UsersSpecifiedPath) then
  begin
    result            := UTF8ToUTF16(UsersSpecifiedPath);
    outputmessage     := 'Container will be saved to existing folder : ' + UsersSpecifiedPath;
    lstrcpyw(Buf, outputmessage);
    XWF_OutputMessage(@Buf[0], 0);
  end
  else
  begin
    OutputOK := ForceDirectories(UsersSpecifiedPath);
    if OutputOK then
    begin
      result            := UTF8ToUTF16(UsersSpecifiedPath);
      outputmessage     := 'Container will be saved to new folder : ' + UsersSpecifiedPath;
      lstrcpyw(Buf, outputmessage);
      XWF_OutputMessage(@Buf[0], 0);
    end;
  end;
end;

// Returns a human formatted version of the time
function TimeStampIt(TheDate : TDateTime) : string; stdcall; export;
begin
  result := FormatDateTime('DD/MM/YYYY HH:MM:SS', TheDate);
end;

// Renders integers representing bytes into string format, e.g. 1MiB, 2GiB etc
function FormatByteSize(const bytes: QWord): string;  stdcall; export;
var
  B: byte;
  KB: word;
  MB: QWord;
  GB: QWord;
  TB: QWord;
begin

  B  := 1;         // byte
  KB := 1024 * B;  // kilobyte
  MB := 1024 * KB; // megabyte
  GB := 1024 * MB; // gigabyte
  TB := 1024 * GB; // terabyte

  if bytes > TB then
    result := FormatFloat('#.## TiB', bytes / TB)
  else
    if bytes > GB then
      result := FormatFloat('#.## GiB', bytes / GB)
    else
      if bytes > MB then
        result := FormatFloat('#.## MiB', bytes / MB)
      else
        if bytes > KB then
          result := FormatFloat('#.## KiB', bytes / KB)
        else
          result := FormatFloat('#.## bytes', bytes) ;
end;

// Gets the case name, and currently selected evidence object, and the image size
// and stores as a header for writing to HTML output later
// Returns true on success. False otherwise.
function GetEvdData(hEvd : THandle) : boolean; stdcall; export;
const
  BufLen=256;
var
  Buf            : array[0..BufLen-1] of WideChar;
  pBufCaseName   : array[0..Buflen-1] of WideChar;
  CaseProperty, EvdSize, intEvdName : Int64;

begin
  result := false;
  // Get the case name, to act as the title in the output file, and store in pBufCaseName
  // XWF_CASEPROP_TITLE = 1, thus that value passed
  CaseProperty := -1;
  CaseProperty := XWF_GetCaseProp(nil, 1, @pBufCaseName[0], Length(pBufCaseName));

  // Get the item size of the evidence object. 16 = Evidence Total Size
  EvdSize := -1;
  EvdSize := XWF_GetEvObjProp(hEvd, 16, nil);

  // Get the evidence object name and store in pBufEvdName. 8 = abbreviated ext. ev. obj. title (e.g. "HD123, P2)
  intEvdName := -1;
  intEvdName := XWF_GetEvObjProp(hEvd, 8, @pBufEvdName[0]);

  lstrcpyw(Buf, 'Case properties established : OK');
  XWF_OutputMessage(@Buf[0], 0);
  result := true;
end;

// Itterates the list of File Type Descriptors to see if the one that is
// currently the subject of XT_ProcessItem is in our required list
// Returns false if not found. True otherwise.
function LookupFileType(FileTypeDescriptor : string) : boolean; stdcall; export;
var
  i : integer;
begin
  result := false;
  for i := 0 to slFileTypeList.Count -1 do
  begin
    if Trim(slFileTypeList.Strings[i]) = FileTypeDescriptor then
      result := true;
  end;
end;

function PrepareFileTypeList(slName : TStringList) : TStringList; stdcall; export;
begin
  result := nil;
  try
    slName := TStringList.Create;
    slName.Sorted := true; // Itterating a sorted list will be fractionally quicker

    // These are the File Type Descriptors as defined by XWF and as returned by
    // XWF_GetItemType with flags 0x4000000.
    // We may add or remove from this list over time, or on an individual needs basis.

    //   *** Documents
    slName.Add('Automatic saving document');
    slName.Add('MS Word');
    slName.Add('WordPad');
    slName.Add('MS Word (MacBinary)');
    slName.Add('MS Word Document macro-enabled');
    slName.Add('MS Word 2007');
    slName.Add('MS Word template');
    slName.Add('MacroDocument Template');
    slName.Add('MS Word 2007 template');
    slName.Add('Lotus Word Pro');
    slName.Add('Mac Write');
    slName.Add('OpenOffice Impress');
    slName.Add('OpenOffice Writer');
    slName.Add('MS OneNote');
    slName.Add('OmniPage Document');
    slName.Add('Presentation Template');
    slName.Add('OpenDocument text template');
    slName.Add('Apple iWork Pages');
    slName.Add('Adobe Acrobat');
    slName.Add('MS PowerPoint');
    slName.Add('PowerPoint Open XML Macro-Enabled Slide Show');
    slName.Add('MS PowerPoint 2007');
    slName.Add('MS PowerPoint');
    slName.Add('PowerPoint Open XML Macro-Enabled Presentation');
    slName.Add('Publisher Document');
    slName.Add('Rich Text');
    slName.Add('StarOffice Writer');
    slName.Add('StarOffice template');
    slName.Add('Word Document Backup');
    slName.Add('WordPerfect');
    slName.Add('MS Works');
    slName.Add('Windows Write');
    //   ***Spreadsheets
    slName.Add('Comma-seperated values');
    slName.Add('FrameMaker/Lotus 1-2-3 spreadsheet');
    slName.Add('Lotus 1-2-3 release 3.x spreadsheet');
    slName.Add('Apple iWork Numbers spreadsheet');
    slName.Add('OpenOffice Calc');
    slName.Add('OpenOffice Calc template');
    slName.Add('StarOffice spreadsheet');
    slName.Add('Tab-seperated values');
    slName.Add('MS Works/Lotus 1-2-3');
    slName.Add('Works Spreadsheet');
    slName.Add('Excel/Addin');
    slName.Add('XLSX Macro-Enabled');
    slName.Add('Excel Chart');
    slName.Add('MS Excel backup');
    slName.Add('Excel XLL Add-In');
    slName.Add('MS Works spreadsheet');
    slName.Add('MS Excel');
    slName.Add('XML Workbook');
    slName.Add('Excel Binary Spreadsheet');
    slName.Add('MS Excel 2007');
    slName.Add('MS Excel template');
    slName.Add('MS Excel 2007 template');
    slName.Add('MS Excel 4.0 workbook');
    // *** E-Mails
    slName.Add('Kerio Connect');
    slName.Add('TNEF');
    slName.Add('Tobit Email');
    slName.Add('Microsoft Exchange diagnostic');
    slName.Add('FoxMail, Lotus Notes');
    slName.Add('Lotus CCMail');
    slName.Add('Pegasus');
    slName.Add('Outlook Express');
    slName.Add('Sage ACT!');
    slName.Add('E-mail message');
    slName.Add('OSX Tiger Mail');
    slName.Add('Attachment');
    slName.Add('Windows compr. enh. metafile');
    slName.Add('MS Exchange E-mail Database');
    slName.Add('Outlook favorites');
    slName.Add('T-online, Kerio Connect');
    slName.Add('The Bat! mbox');
    slName.Add('winmail');
    slName.Add('GroupMail Message');
    slName.Add('SmarterMail Group');
    slName.Add('Outlook account');
    slName.Add('Lotus Notes');
    slName.Add('Pocomail, Barca');
    slName.Add('IncrediMail animation');
    slName.Add('IncrediMail eCard');
    slName.Add('ACT! Internet Mail');
    slName.Add('IncrediMail messages');
    slName.Add('Mailbag Assistant');
    slName.Add('Generic mailbox');
    slName.Add('Opera');
    slName.Add('Eudora, PocoMail, Barca');
    slName.Add('OE4 Mailbox');
    slName.Add('Arcsoft MultiMedia Email 3.0 message');
    slName.Add('Internet Mail Message');
    slName.Add('MIME');
    slName.Add('MailMessage File');
    slName.Add('The Bat!');
    slName.Add('Mail Summary');
    slName.Add('MS Outlook, PMMail');
    slName.Add('Windows Vista Mail');
    slName.Add('Inline E-mail Attachment');
    slName.Add('Outlook AutoComplete');
    slName.Add('Live Mail news message');
    slName.Add('Windows Mail');
    slName.Add('MS Outlook template');
    slName.Add('olk14Contact');
    slName.Add('MS Outlook 2011 for Mac');
    slName.Add('nk2 for Mac');
    slName.Add('MS Outlook 2014 for Mac');
    slName.Add('Mac Outlook');
    slName.Add('AOL Global Access Information');
    slName.Add('MS Outlook');
    slName.Add('Eudora Mapping Mailbox');
    slName.Add('MozBackup');
    slName.Add('AOL');
    slName.Add('Outlook rule');
    slName.Add('StarOffice Mail');
    slName.Add('Firefox');
    slName.Add('StarOffice Mail document');
    slName.Add('Netscape');
    slName.Add('Transport neutral');
    slName.Add('Eudora table');
    slName.Add('IMAP Server');
    slName.Add('Thunderbird mail message');
    slName.Add('MS Exchange shortcut');
    slName.Add('Zimbra');
  finally
    result := slName;
  end;
end;

// This is used for every evidence object when executed via RVS and for each item
// XT_ProcessItem is called
function XT_Prepare(hVolume, hEvidence : THandle; nOpType : DWord; lpReserved : Pointer) : integer; stdcall; export;
const
  BufLen=256;
var
  outputmessage, ContainerFilename  : array[0..MAX_PATH] of WideChar;
  Buf     : array[0..Buflen-1] of WideChar;
  success : boolean;


begin
  itemcount                := 0;
  infoflag_Error           := 0;
  infoflag_Error           := 0;
  infoflag_NotVerified     := 0;
  infoflag_TooSmall        := 0;
  infoflag_TotallyUnknown  := 0;
  infoflag_Confirmed       := 0;
  infoflag_NotConfirmed    := 0;
  infoflag_NewlyIdentified := 0;
  infoflag_MisMatch        := 0;

  slFileTypeList := PrepareFileTypeList(slFileTypeList);

  if nOpType <> 1 then
  begin
    MessageBox(MainWnd, 'Advisory: ' +
                        ' Please execute this X-Tension via the RVS (F10) option only' +
                        ' and apply it to your selected evidence object(s).'
                       ,'XWF Auto CTR', MB_ICONINFORMATION);
    // Tell XWF to abort if the user attempts another mode of execution, by returning -3
    result := -3;
  end
  else
    begin
      // Get the total item count for this particular evidence object, regardless of exclusions
      itemcount     := XWF_GetItemCount(nil);
      outputmessage := 'Total item count in this evidence object : ' + IntToStr(itemcount);
      lstrcpyw(Buf, outputmessage);
      XWF_OutputMessage(@Buf[0], 0);

      // Now gather the evidence object metadata
      success := GetEvdData(hEvidence);
      // Only continue if metadata retrieved OK. Abort otherwise.
      if success then
      begin
        outputmessage := 'Creating evidence container...';
        lstrcpyw(Buf, outputmessage);
        XWF_OutputMessage(@Buf[0], 0);

        if OutputFolderIsSpecified = false then
        begin
          OutputFolder := GetOutputLocation();
          if DirectoryExists(OutputFolder) then
          begin
            OutputFolderIsSpecified := true;
          end
          else
          begin
            outputmessage := 'Could not create output folder. Aborting execution.';
            lstrcpyw(Buf, outputmessage);
            XWF_OutputMessage(@Buf[0], 0);
            OutputFolderIsSpecified := false;
          end;
        end;

        if OutputFolderIsSpecified = true then
        begin
          ContainerFilename := OutputFolder + pBufEvdName + '.ctr';
          outputmessage := 'Will attempt to write container to ' + ContainerFilename;
          lstrcpyw(Buf, outputmessage);
          XWF_OutputMessage(@Buf[0], 0);

          // Try to create the output container. If fails, abort.
          hContainerFile := XWF_CreateContainer(@ContainerFilename, XWF_CTR_TOPLEVELDIR_COMPLETE, lpReserved);
          if hContainerFile > 0 then
          begin
            outputmessage := 'Evidence container opened and ready for files. Adding files...please wait';
            lstrcpyw(Buf, outputmessage);
            XWF_OutputMessage(@Buf[0], 0);

            // We need our X-Tension to return 0x01, 0x08, 0x10, and 0x20, depending on exactly what we want
            // We can change the result using or combinations as we need, as follows:
            // Call XT_ProcessItem for each item in the evidence object : (0x01)  : XT_PREPARE_CALLPI
            result := XT_PREPARE_CALLPI;  // Tell XWF to proceed and call XT_ProcessItem
            CurrentVolume := hVolume;
          end
          else
          begin
           outputmessage := 'Unable to create or write to evidence container: ' + ContainerFilename;
           lstrcpyw(Buf, outputmessage);
           XWF_OutputMessage(@Buf[0], 0);
           result := -3  // Tell XWF to abort
          end;
        end;

      end   // Metdata lookup end.
      else  // Metatdata could not be retrived properly.
        begin
          outputmessage := 'Unable to retrieve case properties...aborting execution.';
          lstrcpyw(Buf, outputmessage);
          XWF_OutputMessage(@Buf[0], 0);
          result := -3  // Tell XWF to abort
        end;
    end;

    // XWF will intelligently skip certain items due to, for example, first cluster not known etc
    // In the future, if we need to change it to do all items regardless, change the result
    // of this function to 0 and then uncomment the for loop code below.
    // Then XWF will call XT_ProcessItem for every item in the evidence object
    // even if the file is non-sensicle.
    {
    for i := 0 to itemcount -1 do
    begin
     XT_ProcessItem(i, nil);
    end;
    }
end;

// Examines each item in the selected evidence object. The "type category" of the item
// is then added to a string list for traversal later. Must return 0! -1 if fails.
function XT_ProcessItemEx(nItemID : LongWord; lpReserved : Pointer) : integer; stdcall; export;
const
  BufLen=256;
var
  ItemSize          : Int64;
  lpTypeDescr       : array[0..Buflen-1] of WideChar;
  Buf               : array[0..Buflen-1] of WideChar;
  lpReportTableString : array[0..Buflen-1] of WideChar;
  outputmessage     : array[0..Buflen-1] of WideChar;
  itemtypeinfoflag, intCopyResult, ReportTableAdditionSuccess : integer;
  hItem : THandle;
  IsItAPicture, AddFileToContainerOrNot : boolean;
begin
  ItemSize := -1;

  // Make sure buffers are empty and filled with zeroes
  FillChar(lpTypeDescr, Length(lpTypeDescr), #0);
  FillChar(lpReportTableString, Length(lpTypeDescr), #0);
  FillChar(Buf, Length(lpTypeDescr), #0);

  // Get the size of the item
  ItemSize := XWF_GetItemSize(nItemID);
  if ItemSize > 0 then inc(TotalDataInBytes, ItemSize);

  // For every item, add its file category (e.g. "Documents", "Spreadhseets" etc) to a list
  // $40000000 is the value to pass to get the category (e.g. "Pictures"),
  // instead of the type descriptor which is 0x20000000 (e.g. "MS Word")
  // Because of the size of the pictures group, we grab all of those.
  // If the item is not a picture, then we do a lookup on its type descriptor.
  // This is why v18.9 or higher is required, as this flag was not avail in earlier versions

  IsItAPicture := false;

  itemtypeinfoflag := XWF_GetItemType(nItemID, @lpTypeDescr, Length(lpTypeDescr) or $40000000);
  if (lpTypeDescr = 'Pictures') then
  begin
    IsItAPicture := true
  end
  else IsItAPicture := false;

  if IsItAPicture = false then
  begin
    itemtypeinfoflag := XWF_GetItemType(nItemID, @lpTypeDescr, Length(lpTypeDescr) or $20000000);
  end;

  { API docs state that the first byte in the buffer should be empty on failure to lookup category
    So if the buffer is empty, no text category could be retrieved. Otherwise, classify it. }
  if lpTypeDescr<> #0 then
  begin
    // 3 = Confirmed file
    // 4 = Not confirmed
    // 5 = Newly identified
    if (itemtypeinfoflag = 3) or (itemtypeinfoflag = 4) or (itemtypeinfoflag = 5) then
    begin
      if (lpTypeDescr = 'Pictures') then
      begin
        // Open the file item. Returns 0 if unsuccessfull.
        hItem := XWF_OpenItem(CurrentVolume, nItemID, $01);
        // Copy the item to the container. Returns 0 if unsuccessfull.
        {0x00000001: recreate full original path                                            // ENABLED
         0x00000002: include parent item data (requires flag 0x1)                           // DISABLED currently
         0x00000004: store hash value in container                                          // ENABLED
         0x00000010: store comment, if existent, in container (v19.0 and later)             // DISABLED currently
         0x00000020: store extracted metadata, if available, in container (v19.0 and later) // DISABLED currently
        }
        intCopyResult := 0;
        intCopyResult := XWF_CopyToContainer(hContainerFile, hItem, $01 or $04, 0, -1, -1, lpReserved);
        // Add report table text to show file was exported to container.
        // Only check for failure, which is zero.
        // 1 if the file was successfully and newly associated with the report table,
        // 2 if that association existed before, or
        // 0 in case of failure
        lpReportTableString := 'DFG Sent to CTR';
        ReportTableAdditionSuccess := XWF_AddToReportTable(nItemID, @lpReportTableString[0], $01);
        if ReportTableAdditionSuccess = 0 then
        begin
          outputmessage := 'Unable to create Report Table text entry for item: ' + IntToStr(hItem);
          lstrcpyw(Buf, outputmessage);
          XWF_OutputMessage(@Buf[0], 0);
        end;
        XWF_Close(hItem);

        // If the copy worked, then intCopyResult will now be greater than zero
        if intCopyResult <> 0 then
        begin
          XWF_Close(hItem);
          MessageBox(MainWnd,  ' Error detected whilst adding a file to the container. Aborting. '
                                ,'XWF Auto CTR', MB_ICONINFORMATION);
          exit;
        end;
      end
      else  // It is not a picture, so lets lookup what file type it is, and send it to container if its a match
      begin
        AddFileToContainerOrNot := false;
        AddFileToContainerOrNot := LookupFileType(WideCharToString(@lpTypeDescr[0]));
        if AddFileToContainerOrNot then
        begin
          // Open the file item. Returns 0 if unsuccessfull.
          hItem := XWF_OpenItem(CurrentVolume, nItemID, $01);
          // Copy the item to the container. Returns 0 if unsuccessfull.
          intCopyResult := 0;
          intCopyResult := XWF_CopyToContainer(hContainerFile, hItem, $01 or $04, 0, -1, -1, lpReserved);

          // Add report table text to show file was exported to container.
          // Only check for failure, which is zero.
          // 1 if the file was successfully and newly associated with the report table,
          // 2 if that association existed before, or
          // 0 in case of failure
          lpReportTableString := 'DFG Sent to CTR';
          ReportTableAdditionSuccess := XWF_AddToReportTable(nItemID, @lpReportTableString[0], $01);
          if ReportTableAdditionSuccess = 0 then
          begin
            outputmessage := 'Unable to create Report Table text entry for item: ' + IntToStr(hItem);
            lstrcpyw(Buf, outputmessage);
            XWF_OutputMessage(@Buf[0], 0);
          end;
          XWF_Close(hItem);

          // If the copy worked, then intCopyResult will now be greater than zero
          if intCopyResult <> 0 then
            begin
              XWF_Close(hItem);
              MessageBox(MainWnd,  ' Error detected whilst adding a file to the container. Aborting. '
                                    ,'XWF Auto CTR', MB_ICONINFORMATION);
              exit;
            end;
        end;
      end;
    end;
  end;
  // The ALL IMPORTANT 0 return value!!
  result := 0;
end;


    {
    if itemtypeinfoflag = 0 then       // Not verified
    begin
      inc(infoflag_NotVerified,1);
      slJustTheFileCategories.Add(WideCharToString(@lpTypeDescr[0]));
      inc(ItemsReported, 1);
    end
    else
    if itemtypeinfoflag = 1 then      // Too small, less than 8 bytes
    begin
      inc(infoflag_TooSmall,1);
      slJustTheFileCategories.Add(WideCharToString(@lpTypeDescr[0]));
      inc(ItemsReported, 1);
    end
    else
    if itemtypeinfoflag = 2 then      // Totally Unknown\Unverified
    begin
      inc(infoflag_TotallyUnknown,1);
      slJustTheFileCategories.Add(WideCharToString(@lpTypeDescr[0]));
      inc(ItemsReported, 1);
    end
    else
    if itemtypeinfoflag = 3 then      // Confirmed file
    begin
      inc(infoflag_Confirmed,1);
      slJustTheFileCategories.Add(WideCharToString(@lpTypeDescr[0]));
      inc(ItemsReported, 1);
    end
    else
    if itemtypeinfoflag = 4 then      // Not confirmed file
    begin
      inc(infoflag_NotConfirmed,1);
      slJustTheFileCategories.Add(WideCharToString(@lpTypeDescr[0]));
      inc(ItemsReported, 1);
    end
    else
    if itemtypeinfoflag = 5 then      // Newly identified
    begin
      inc(infoflag_NewlyIdentified,1);
      slJustTheFileCategories.Add(WideCharToString(@lpTypeDescr[0]));
      inc(ItemsReported, 1);
    end
    else
    if itemtypeinfoflag = 6 then      // Mis-match - extension does not match signature
    begin
      inc(infoflag_MisMatch,1);
      slJustTheFileCategories.Add(WideCharToString(@lpTypeDescr[0]));
      inc(ItemsReported, 1);
    end
    else
    if itemtypeinfoflag = -1 then    // XWF had an error running XWF_GetItemType
    begin
      inc(infoflag_Error,1);
    end;
  end
  else
  // If the buffer is empty, null terminated, XWF could not recover a category text value.
  // This should be very rare, because even "Other\Unknown" types are represented in XWF,
  // and returned as "Other\Unknown".
    begin
      slJustTheFileCategories.Add('No category entry - not even "Unknown"');
      inc(ItemsReported, 1);
   end;  }


// Called after all items in the evidence objects have been itterated.
// Return -1 on failure. 0 on success.
function XT_Finalize(hVolume, hEvidence : THandle; nOpType : DWord; lpReserved : Pointer) : integer; stdcall; export;
const
  Buflen=256;
var
  intClosedOK : integer;
  Buf, outputmessage : array[0..Buflen-1] of WideChar;

begin
  slFileTypeList.free;

  intClosedOK := 0;
  intClosedOK := XWF_CloseContainer(hContainerFile, lpReserved);
  if intClosedOK <> 1 then
  begin
    outputmessage := 'Error closing container : ERROR';
    lstrcpyw(Buf, outputmessage);
    XWF_OutputMessage(@Buf[0], 0);
    MessageBox(MainWnd,  ' Error closing container. '
                          ,'XWF Auto CTR', MB_ICONINFORMATION);
    Result := -1;
  end
  else
    begin
      outputmessage := 'Container successfully closed : OK';
      lstrcpyw(Buf, outputmessage);
      XWF_OutputMessage(@Buf[0], 0);
      result := 0;
    end;
end;

// called just before the DLL is unloaded to give XWF chance to dispose any allocated memory,
// Should return 0.
function XT_Done(lpReserved: Pointer) : integer; stdcall; export;
begin
  result := 0;
end;


exports
  XT_Init,
  XT_About,
  XT_Prepare,
  XT_ProcessItemEx,
  XT_Finalize,
  XT_Done,
  // The following functions may not be exported in future. Left in for now.
  GetOutputLocation,
  TimeStampIt,
  FormatByteSize,
  LookupFileType,
  PrepareFileTypeList;
begin

end.



