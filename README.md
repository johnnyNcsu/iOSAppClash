# iOSAppClash
Programmatically identify shared 3rd party app installs on iPhones using hashed lists for privacy.

What if you experience a recurring iPhone issue that is being reported by only a few other users? What if you suspect the issue might arise from an interaction with a 3rd party app but don't know which app might be causing the issue? What if several other users have reported similar behavior but are also unable to identify the cause but also suspect it is related to their profile on the phone?

In this case, it would be useful to have a means to programmatically compare profiles among this subset of users to see if they share something in common that might be a clue to identifying the cause of the unwanted behavior. At the same time, it would be nice if the comparisons could be done while maintaining some degree of privacy to prevent each user from having to disclose possibly sensitive information within their profiles.

The code in this repository aims to allow users to compare the 3rd party app installs on their phones while not openly disclosing the complete manifest of app names to one another. The approach involves generating the full list of apps, hashing that list, and then comparing the hashed list with other user's hashed lists to find matches.

The level of privacy using this approach is limited by the relatively low entropy in the total number of apps available to install and the total number of participants sharing their lists. That is, this technique, while offering "good" privacy, should not be considered strong privacy despite using strong hashing algorithms. For instance, a relatively low effort is needed for a nefarious actor to load their list with a full cadre of 3rd party financial apps in an attempt to discover which financial institutions may be installed on participant devices. For this reason, in addition to hashing each list, participant identities are also concealed with the use of unique ID's. Each list is tagged with a unique ID derived from the UDID installed on the device from which the list is generated. The unique ID is a hash of the UDID, which has a high degree of entropy renedering the generated unique ID as extremely difficult to reverse.

So while it may be possible to intentionally 'spoof' collisions, identifying the user assoicated with those collisions is harder, unless the pool of participants is also small.

While not a perfect method, this is a "good" level of privacy for the intended use. Further, should a participant wish to not risk disclosure of a specific app installed on their device, it's simple enough to manually edit that entry out of the source list prior to generating the hashed files. Of course, that will impact the accuracy of the overall results but this is an acceptable tradeoff.

## Operational Flow

1. Connect your iPhone with a Macintosh computer via USB.
2. Run [Apple's Configurator app](https://apps.apple.com/us/app/apple-configurator/id1037126344?mt=12) to read and export the list of installed 3rd party apps from your device as a csv file.
3. Run the shell script **createMyHashes.sh** with the file you named to contain the exported list as the input source:<br><br>
   `shell prompt$ createMyHashes.sh <filename>`<br><br>
   This will create two files of the form:<br><br>
   ```
   keyAppList_AAAAAA.txt
   upload_AAAAAA.txt
   ```
     where `AAAAAA` is the local identifier created from the hash of the device UDID.<br><br>
5. Share the upload file with other participants on a public upload site.
6. When other participant files are available to download, download those files to your working directory.
7. Run the comparator shell script to check for common apps among devices:<br><br>
   `shell prompt$ compHashLists.sh`<br><br>
   This will create the resulting `histogram.txt` file which contains a histogram showing which apps are present on your local device as well as other participant devices. The histogram will be a left to right series of 6 charater device identifiers written on the line of each app name installed on the local device. The row with the most device identifiers will be the candidate app most likely to be the cause of any aberrant behavior.

8. Share results.




