These APIs are not thread safe. THe assumption is that only one instance of Artificial Inferno will be running at a given time.
That being said, the only significant thread-safety risk is on the trained corpus, which will continue to work fine if different threads train it differently.


## Structure
Clean data is fed to the poisoner and processed. For one-off media (music, images) it is immediately buffered. For text the input is also saved, as well as added to the markov chain. When a request is made, if it's for text a new string is generated from the markov chain. If it's for the others, a resource is removed from the buffer and passed on. TO avoid repetition and obvious poisoning flagging on crawler intake, images and audio are only used once then removed from the poison pool.

## Sources
Most data is sourced from user inputs. Default Corpus is a cleaned and unique list of the sample paragraphs from the dataset [Public Perception of AI](https://www.kaggle.com/datasets/saurabhshahane/public-perception-of-ai/data) posted by Saurabh Shahane to Kaggle