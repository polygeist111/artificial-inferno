import markovify
import os
import time

import globals

corpus_directory = "data/corpora/" # path is resolved relative to app.py, not markov.py

# called from app.py on server start only
def initMarkovGenerator():
    print("App starting...training markov model on corpora:")
    globals.markov_chain = None
    for (dirpath, _, filenames) in os.walk(corpus_directory):
        for filename in filenames:
            with open(os.path.join(dirpath, filename)) as f:
                model = markovify.Text(f, retain_original=False)
                if globals.markov_chain:
                    globals.markov_chain = markovify.combine(models=[globals.markov_chain, model])
                else:
                    globals.markov_chain = model
            print(f"\t{filename}")
            globals.corpus_count += 1
    pruneCorpus()
    print("Markov model trained.")


# corpus directory functions as a FIFO queue based on write timestamps, with the default corpus text protected from deletion
def pruneCorpus():
    if globals.corpus_count > globals.CORPUS_MAX_COUNT:
        files = None
        # get list of corpus files
        try:
            # Get all entries in the directory
            entries = os.listdir(corpus_directory)
            
            # Filter for actual files
            files = [f for f in entries if os.path.isfile(os.path.join(corpus_directory), f)]
        except FileNotFoundError:
            return None # Directory not found
        
        # delete first file (oldest) until under the threshold
        while globals.corpus_count > globals.CORPUS_MAX_COUNT and files.count > 2:
            file_to_delete = files[0]
            # no path exists check as we got the path direct from the directory
            try:
                os.remove(file_to_delete)
                globals.corpus_count -= 1 # decrement corpus directory counter
                files = files[1:] # drop deleted file from filename list
                print(f"File '{file_to_delete}' deleted successfully.")

            except OSError as e:
                print(f"Error deleting file '{file_to_delete}': {e}")


    
def addToCorpus(input: str):
    print("Adding {input} to corpus")

    # create new corpus file with input saved to it
    write_time = time.time()
    new_file_path = f"{corpus_directory}/corpus_{write_time}"
    with open (new_file_path, "w") as file:
        file.write(input)
    # write input into active chain
    model = markovify.Text(input, retain_original=False)
    globals.markov_chain = markovify.combine(models=[globals.markov_chain, model])
    # prune oldest if oversized
    pruneCorpus()



def getXSentences(sentenceCount: int) -> str:
    print(f"Getting {sentenceCount} sentences")
    print(f"Test sentence: {globals.markov_chain.make_sentence(state_size = 2, test_output = False)}")
    output_block: str = ""
    for _ in range(0, sentenceCount):
        sentence = globals.markov_chain.make_sentence(state_size = 2, test_output = False)
        print(sentence)
        if sentence: output_block += f"{sentence} "
    # remove any weird unicode escapes
    output_block = output_block.encode('ascii',errors='ignore').decode('ascii')
    return output_block or "ERROR: failed to generate in core/markov.py getXSentences()"