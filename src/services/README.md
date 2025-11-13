These APIs are not thread safe. THe assumption is that only one instance of Artificial Inferno will be running at a given time.
That being said, the only significant thread-safety risk is on the trained corpus, which will continue to work fine if different threads train it differently.


## Structure
Clean data is fed to the poisoner and processed. For one-off media (music, images) it is immediately buffered. For text the input is also saved, as well as added to the markov chain. When a request is made, if it's for text a new string is generated from the markov chain. If it's for the others, a resource is removed from the buffer and passed on. TO avoid repetition and obvious poisoning flagging on crawler intake, images and audio are only used once then removed from the poison pool.

## Sources
Most data is sourced from user inputs. Default Corpus is a cleaned and unique list of the sample paragraphs from the dataset [Public Perception of AI](https://www.kaggle.com/datasets/saurabhshahane/public-perception-of-ai/data) posted by Saurabh Shahane to Kaggle

## Testing Locally
To run the API on localhost, navigate to the `services` subdirectory and execute `flask run --debug`. By default, it runs on port 5000. Below are some sample commands to test the API, with the assumption that they're being called from the project root:

### Text
Text is handled at the /poison/text endpoint.
When reading text, you can specify a number of sentences to return between 1 and 100. Anything outside these bounds will be coerced to the nearer bound. The default sentence count is 3, and if the specified amount fails a fallback attempt is made at the default amount.<br/><br/>
**READ**<br/>
No specification:
```
curl -X GET \
  127.0.0.1:5000/poison/text
```
Requesting 5 sentences:
```
curl -X GET \
  -H "Content-Type: application/json" \
  -d '{"numsentences": 5}' \
  127.0.0.1:5000/poison/text
```
**WRITE**<br/>
When writing text, you must specify the content. This content will both be added to the active Markov model and saved in plaintext for model training on server restart. Please do not upload any sensitive information. No personally identifying information will be saved, only the content string as uploaded and the timestamp of its reception.
```
curl -X POST \                        
  -H "Content-Type: application/json" \
  -d '{"content": "He seems shy, grateful, sometimes sad and always, to Leigh Anne, an open source effort to create a blueprint drawing for this definition. Made by Mr. McQueen for Givenchy Haute Couture. The project  a simplifying analogy rather than automate, flight. He begins with what Omen says. Why caused Stanley to swerve off the fiscal cliff, suggested Lou Dobbs on Fox Business News. This occasionally dark but wonderfully original simulation occasionally suggests a sequence of moves the students in the near future, Frank, an economics professor at the New York Times, just wait until there was existed in the ocean. The history of tech tells A.I. backers to hang in the Bits blog writes. An obituary on Thursday a specially configured version of that conceit helped to smother the blaze, giving fire crews a chance of transforming into other vehicles, artificial intelligence system that could help people to take over BellSouth -- could give the whole point of the spectrum, too. In particular, an artificial intelligence hidden somewhere in the shuttles, was military. The body is a lot of things to buy. "}' \
  127.0.0.1:5000/poison/text
```
### Images
Images are handled at the /poison/images endpoint
The service does not perform any operations on images, it only buffers them for more efficient calling by the tarpit. As with text, no information is saved from the upload besides the timestamp of its reception and the file itself. Please only upload JPGs/JPEGs. All returned files will be suffixed .JPG.
**READ**<br/>
Note the verbose flag. Since we've specified an output, if this errors (e.g. the server has no images buffered) that text will still be written to the file. By flagging it verbose, we can now see the actual response code to know if it succeeded.
```
curl -v --output dev-help/samples-output/requested-img.jpg -X GET \
  127.0.0.1:5000/poison/images
```
**WRITE**<br/>
Must be JPG/JPEG
```
curl -X POST \
  -F "image=@dev-help/samples-input/rhino_owl_mask_gridview.jpeg" \
  127.0.0.1:5000/poison/images
```
### Sound
**READ**<br/>
```
curl -v --output dev-help/samples-output/requested-audio.mp3 -X GET \
  127.0.0.1:5000/poison/audio
```
```
curl -v --output dev-help/samples-output/requested-audio.mp3 -X GET \
  -H "Content-Type: application/json" \
  -d '{"clip_duration": 5}' \
  127.0.0.1:5000/poison/audio
```
**WRITE**<br/>
Must be MPEG (e.g. MP3)
```
curl -X POST \
  -F "audio=@dev-help/samples-input/minecraft_eating_sound_effect_8s.mp3" \
  127.0.0.1:5000/poison/audio
```

## TODO:
Ensure consistent format for log messages, use of log levels (specifically, ensure any log message from an internal error e.g. bad hardcoded filepath ends program execution)
