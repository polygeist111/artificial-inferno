import markovify

# configurable constants
CORPUS_MAX_COUNT = 10001 # 1 is reserved for seed corpus, others are user-generated

# runtime vars
markov_chain: markovify.Text = None
corpus_count: int = 0
