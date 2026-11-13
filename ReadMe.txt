*****************************************************
*** Lead King Phone Broadcast Setup and Operation ***
*****************************************************
Technical Support.: creator hub creator network
Phone.............: 1 876-887-5573
Email.............: creatorhubcreatornetwork@gmail.com
Support Hours.....: 9am thru 3pm Mon thru Fri Mountain Time

Index: 
   - Section 1. Setup
   - Section 2. Call List Format
   - Section 3. In Call Coding
   - Section 4. Files Included With This Software

Our Contact Information
   - 1 876-887-5573 Sales Support
   - creatorhubcreatornetwork@gmail.com
   - creatorhubcreatornetwork@gmail.com

************************
*** VOIP Information ***
************************
Requirement #1............: Residential plans don't support Call Transfer/Blind Transfer.
Requirement #2............: VOIP Provider must not use a Proxy Server, only 1 server can be used.
Requirement #3............: VOIP Provider must support BLIND Transfer - AKA Unattended Call Transfer.
Requirement #4............: VOIP Provider must support these Bria, Zoiper and SoftPhonePro.
Requirement #5............: VOIP Provider must provide Soft Phone (SIP) Credentials.

******************************
*** Sound File Information ***
******************************
Get Sound File From......: www.fiverr.com
Search For...............: Voice Over
Note 1...................: $5.00 to $10.00 <-- Typical Cost For Sound File
Note 2...................: Sound file can be either WAV or MP3.
Note 3...................: Sound file recording format must be 8000hz, 32 Bit, Mono


***********************
*** Section 1. Seup ***
***********************
1. To load a sample VOIP setup file
   - Locate the "VOIP Settings Section".
   - Click the "Open" button and browse to your Desktop.
   - Open the "Lead King Phone Broadcast" folder.
   - Double click "1_VOIP_Settings.txt".

2. To load a sample "Call List" into the "Call Grid"
   - Locate the "Open" button which is located above the "Call" grid, click it and browse to your Desktop. 
   - Open the "Lead King Phone Broadcast" folder.
   - Double click "2_Call_List.txt".

3. To load the sample "Introduction Message" sound file
   - Locate the "Introduction Section".
   - Click the "Open" button and browse to your Desktop.
   - Open the "Lead King Phone Broadcast" folder.
   - Double click "3_Intro Message.wav".
   - Click "Play" to hear the message, and "Stop" to stop playing the message.
   - Set "Replay This Message" to correspond with the "Phone Key Pad" number when pressed.
   - Set "Opt Out" which corresponds with the "Phone Key Pad" number when pressed.

4. To load the sample "Leave A Voice Mail Message Prompt" sound file
   - Locate the "Leave A Voice Mail Message Prompt" section.
   - Click the "Open" button and browse to your Desktop.
   - Open the "Lead King Phone Broadcast" folder.
   - Double click "4_Leave Your Message.wav".
   - Click "Play" to hear the message, and "Stop" to stop playing the message.
   - Set "Leave A Voice Mail" to correspond with the "Phone Key Pad" number when pressed.
   - Set "Opt Out" which corresponds with the "Phone Key Pad" number when pressed.

5. Setting the "Force Hangup"
   - Locate the "VOIP Settings Section".
   - Set "Force Hang Up In Seconds".
   - Note 1: This value should be 10 seconds longer than the "Introduction Message" length.
   - Note 2: Force Hang Up prevents unanswered calls from tying up the broadcast.

6. Set the location to store your "Voice Mail Messages"
   - Locate the "VOIP Settings" section.
   - Click the "Select" button and choose a file folder to store "Voice Mail Messages".
   - Note: Voice Mail Messages are recorded messages left by the called party.

7. Setup "Call Transfer"
   - Locate the "VOIP Settings" section.
   - Locate the "Transfer To" and enter the phone number, use the 10 digit format, i.e., "8005551212".
   - Set "Press This Key" to correspond with the "Phone Key Pad" number when pressed.
   - Note: Call Transfer is not correctly supported by all VOIP vendors which we have no control over.

8. Setup Call Scheduleing
   - Locate the "Schedule" section.
   - Set the "Start Date".
   - Set the "Start Time" and "Stop Time".
   - Check the "Enable Schedule".
   - Click "Start Schedule".
   - Note: The Schedule "Start Date" and "Start Time" must be a future date.

9. Setup Email Notification
   - Locate the "Leave A Voice Mail Message Prompt" section.
   - Click the "+" symbol which will open the Email property page.
   - Enter Username, Password, Server, Port, Display Name, From Email and Send Email To for testing.
   - Click the "Test" button. If testing passes, click the "+" symbol to close the Email property page.
   - Check the "Send Email Notice"
   - Lead King will now send you an email with the Sound File attached.
   - Note: Email Notification will send you an email with called party information and WAV file attached.

**********************************************
*** Section 2. Section 2. Call List Format ***
**********************************************
1. The "Call List" data grid contains 15 columns, they are;
   - Phone
   - Company
   - City
   - ST
   - Zip
   - ContactName
   - SICDescription
   - SICCode
   - DateDialed
   - Action
   - RecordedMessage
   - CallLog
   - Undefined1
   - Undefined2
   - Undefined3 

2. The "Call List" import file format is a TAB seperated text file with fields that match the above
   data grid columns.
   - Note 1: Included with Lead King is a sample "Call List". Please see "Section 1, Item 2".
   - Note 2: We recommend that you use MS Excel when creating your Call List.

3. Entering phone numbers
   - Phone numbers can be manually entered directly into the "Call List" data grid.
   - Call lists can also be imported. Please see "Section 1, Item 2".
   - Note 1: All phone numbers must use the 10 digit format, i.e., "8005551212".
   - Note 2: We recommend that you use MS Excel when creating your Call List.

*********************************
*** Section 3. In Call Coding ***
*********************************
1. During "In Call" processing, all calls will conclude with 1 of the following "Action Codes"
   - Dialed . . . . . . . . . : Phone rang until "Force Hangup" occured
   - Transfer . . . . . . . . : Recipient selected "Call Transfer"
   - Left Message . . . . . . : Recipient left a "Voice Mail Message"
   - Completed. . . . . . . . : Call was answered and the "Introduction Message" was played
   - OptOut . . . . . . . . . : Prospect pressed "Opt Out". 
   - Error. . . . . . . . . . : Invalid phone number

****************************************************
*** Section 4. Files Included With This Software ***
****************************************************
a. 1_VOIP_Settings.txt. . . . : Holds VOIP Settings
b. 2_Call_List.txt. . . . . . : Sample Call List
c. 3_Intro Message.wav. . . . : Sample Introduction Sound File
d. 4_Leave Your Message.wav . : Sample "Leave Your Message" Sound File
e. audacity-win-2.0.6.exe . . : Free Sound Recording Software
f. BroadcastLite.exe. . . . . : Executable Program File
g. EULA.pdf . . . . . . . . . : End User License Agreement
h. ReadMe.txt . . . . . . . . : Read Me File
i. VoIPSDK.dll. . . . . . . . : VOIP PBX Support File
