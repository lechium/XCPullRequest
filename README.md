XCPullRequest
=============

XCode plugin to implement native pull requests

Pre-Requisites
==============

- Mavericks (10.9)+ Server running on separate machine with Xcode server and Web server active
- xcpullreqd (target in this project) built and installed in /Library/Server/Web/Data/Sites/Default/ on above server
- pull_admins.plist updated with real email address array in /Library/Server/Web/Data/Sites/Default/ on above server
- upload.php in /Library/Server/Web/Data/Sites/Default/ on above server
- uploads folder in /Library/Server/Web/Data/Sites/Default/ on above server with following owners and permissions: drwxrwxrwx 70:0
- /private/var/tmp on Mavericks server must be writable by 70:0

This readme will be updated with explicit instructions on this setup in the near future, and in depth blog posts will be written to better explain how this all works and what I did to implement these different features into Xcode.

The goal is to get this plugin added to the list of Alcatraz plugins to enable the easiest installation into XCode as possible. However, the pre-requisite setup above is still necessary to be done manually.
