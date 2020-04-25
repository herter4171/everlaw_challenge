# everlaw_challenge

## General Discussion
One thing that was a bit unclear to me was whether the csv parsing should ideally happen locally or on the remote, but I think the distinction would be clear in a real-world context.  Since parsing locally was the path of least resistance, that’s what I went with, so for this case, “publish” means uploading the text files to the remote htdocs folder.  

The other concern I have is with the efficiency of how I’m parsing.  Since the instructions specify using command line tools over a higher-level programming language, I just run through the lines and dump a grep count into a text file when a new string is encountered based on existing outputted text file names.  This was the quickest approach I tried, but I’m still a bit on edge over how computationally expensive doing repeated grep counts could be on larger files.

## Files and Sample Inputs
Relevant files are as follows.
* [herter_the_script.sh](herter_the_script.sh): Shell script with all desired functionality
* [herter_the_script.log](herter_the_script.log): Outcome from running the above using
    * A fresh Ubuntu 18.04 EC2 instance
    * URL: https://data.ok.gov/sites/default/files/unspsc%20codes_3.csv
    * Column: 4

## Assumptions
### Using Ubuntu 18.04 instead of 16.04
I got this one cleared from the outset.  There aren’t any free-tier eligible AMIs for Ubuntu 16.04 anymore, so target platform for the remote is Ubuntu 18.04.

### Remote Username
Assuming “ubuntu” as the remote user is common sense for this exercise, but it’s still an assumption.

### Use of Docker and Docker Compose
Since the prompt said the script “can employ any number of additional resources” and “we encourage and expect the script to install additional software” on the remote, it is assumed that installing Docker and Docker Compose for bringing a web server online is a valid approach for the exercise.  This is also the path of least resistance for me, because a lot of my work involves containers.

### Inputted Column Number Uses Awk Indexing
Since awk is used to extract the desired column, the range of valid column numbers goes from one to the total number of columns.  If a number outside of the range is given, the user is made aware of the allowable range of values for column number input.

### Column Headings Should be Excluded From Parsing
Based on my read of the prompt, what we’re after are counts for occurrences of column data, and I don’t think headings fall into that category.

### Ignoring Certain Characters
I was told to only worry about alphanumeric characters and spaces, so I have ignored cases that involve obnoxious things like percent and star symbols.  Even though double quotes can be ignored, they showed up often enough to warrant removal.  Leading spaces are also parsed out and are a likely byproduct of quoted strings with commas in them.

### URL Extensions
I honestly struggled a lot with whether to make this assumption or not.  The expectation here is that the URL is a direct link to a csv file, thereby ending in *.csv.  I only mention the distinction, because some had a URL ending in /csv and others had ugly suffixes like “?Download.”  Dealing with these variants seemed out of scope, and for a real-world scenario, I would expect a standard similar to this to be set so that intent is clear from simple inspection of the URL.  Had it seemed in-scope, I would have put more time into establishing a clean way of handling any arbitrary URL and ensuring the download is actually a csv file.

### A Single File is Desired for Submission
The prompt seems to indicate that supplemental files might be okay to have along-side the script, but my read on the subtext is that it is desirable to have a single shell script to take care of everything.  Normally, I tend to go wide with scripting instead of having a monolith, because having several files open is easier than scrolling a bunch.  There’s also almost always a Git repository in play, which obviously simplifies things.  Having a single file is probably a self-imposed challenge, but it was a fun exercise.

### Cleaning up Files on the Local  Machine
The prompt says, “Any changes the script causes to the local machine must be temporary in nature.”  Even though the sentence that directly follows refers to installing software (on the remote), I’m going to assume that “any changes” includes files generated by the script in the course of running.  Files are only retained if the script doesn’t exit gracefully, mainly so that the user doesn’t have to download the potentially large csv file repeatedly in the course of debugging.

### Properly Formatted CSV
I ran into a lot of edge cases that distracted from the task at hand, and I can see why I’ve been instructed to expect a simply formatted csv file.
