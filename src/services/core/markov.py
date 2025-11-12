"""
Module to handle all markov chain/babble actions
"""

### Imports
# Standard
import os
import time

# Third Party
import markovify

# Local
import global_vars
import core.messaging as messaging


corpus_directory = global_vars.CORPORA_DIRECTORY # path is resolved relative to app.py, not markov.py

# called from app.py on server start only
def initMarkovGenerator():
    messaging.console_out("App starting...training markov model on corpora:", messaging.LogLevel.INFO)
    global_vars.markov_chain = None
    for (dirpath, _, filenames) in os.walk(corpus_directory):
        for filename in filenames:
            with open(os.path.join(dirpath, filename)) as f:
                model = markovify.Text(f, retain_original=False)
                if global_vars.markov_chain:
                    global_vars.markov_chain = markovify.combine(models=[global_vars.markov_chain, model])
                else:
                    global_vars.markov_chain = model
            messaging.console_out(f"\t{filename}", messaging.LogLevel.INFO)
            global_vars.corpus_count += 1
    pruneCorpus()
    messaging.console_out("Markov model trained", messaging.LogLevel.SUCCESS)


# corpus directory functions as a FIFO queue based on write timestamps, with the default corpus text protected from deletion
def pruneCorpus():
    if global_vars.corpus_count > global_vars.CORPUS_MAX_COUNT:
        files = None
        # get list of corpus files
        try:
            # Get all entries in the directory
            entries = os.listdir(corpus_directory)
            
            # Filter for actual files
            files = [f for f in entries if os.path.isfile(os.path.join(corpus_directory), f)] # type: ignore
        except FileNotFoundError:
            return None # Directory not found
        
        # delete first file (oldest) until under the threshold
        while global_vars.corpus_count > global_vars.CORPUS_MAX_COUNT and len(files) > 2:
            file_to_delete = files[0]
            # no path exists check as we got the path direct from the directory
            try:
                os.remove(file_to_delete)
                global_vars.corpus_count -= 1 # decrement corpus directory counter
                files = files[1:] # drop deleted file from filename list
                messaging.console_out(f"File '{file_to_delete}' deleted successfully.", messaging.LogLevel.SUCCESS)

            except OSError as e:
                messaging.console_out(f"Error deleting file '{file_to_delete}': {e}", messaging.LogLevel.INFO)


    
def addToCorpus(input: str):
    messaging.console_out(f"Adding {input} to corpus", messaging.LogLevel.INFO)

    # create new corpus file with input saved to it
    write_time = time.time()
    new_file_path = f"{corpus_directory}/corpus_{write_time}"
    with open (new_file_path, "w") as file:
        file.write(input)
    # write input into active chain
    model = markovify.Text(input, retain_original=False)
    global_vars.markov_chain = markovify.combine(models=[global_vars.markov_chain, model])
    # prune oldest if oversized
    pruneCorpus()



def getXSentences(sentenceCount: int) -> str:
    messaging.console_out(f"Getting {sentenceCount} sentences", messaging.LogLevel.INFO)
    output_block: str = ""
    for _ in range(0, sentenceCount):
        sentence = global_vars.markov_chain.make_sentence(state_size = 2, test_output = False)
        if sentence: output_block += f"{sentence} "
    # remove any weird unicode escapes
    output_block = output_block.encode('ascii',errors='ignore').decode('ascii')
    return output_block or "ERROR: failed to generate in core/markov.py getXSentences()"