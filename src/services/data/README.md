- `buffer`: Parent folder for all files fully processed, waiting to be served<br/>
    - `audio`: Audio files<br/>
    - `corpora`: Text files for markov model<br/>
    - `images`: Image files<br/>
- `intake`: Staging area for files yet to be processed (e.g. input audio prior to shredding)<br/>
- `out-for-delivery`: Waiting area for files served to clients. All files here are earmarked for timed deletion when entered<br/>

## TODO
- Build proper audio GET function to stitch clips together
- Restructure file globals as dictionary, update functions to match
- Implement buffer safety for intake and delivery
- Deprecate validateDirectorySize
