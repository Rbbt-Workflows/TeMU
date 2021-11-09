require 'rbbt-util'
require 'rbbt/workflow'

Misc.add_libdir if __FILE__ == $0

require 'te_MU'

module TeMU
  extend Workflow

  input :dataset, :file, "Dataset directory or name", nil, :nofile => true
  input :model, :select, "Model directory or name", nil, :select_options => TeMU.models(:NeuroNER)
  input :embeddings, :select, "Embeddings file", TeMU.models(:embeddings).first, :select_options => TeMU.models(:embeddings)
  task :neuro_ner => :tsv do |dataset, model,embeddings|

    params = file('parameters.ini')
    deploy = file('deploy')
    output = file('output')

    model = Rbbt.share.models.TeMU.NeuroNER[model].find unless File.exists?(model) || model.include?("/")
    embeddings = Rbbt.share.models.TeMU.embeddings[embeddings].find unless File.exists?(embeddings) || embeddings.include?("/")

    Open.mkdir deploy

    if not Misc.is_filename? dataset
      extension = '.tar.gz'
      new_dataset_file = 'archive.' + extension
      Open.write(new_dataset_file, dataset, :mode => 'wb')
      dataset =  new_dataset_file
    end

    # setup deploy directory
    if File.directory?(dataset)
      Dir.glob(File.expand_path(dataset) + "/*").each do |file|
        Open.ln_s file, deploy
      end
    elsif dataset =~ /\.t(ar\.)?gz$/i
      Misc.untar(dataset, deploy)
    elsif dataset =~ /\.t(ar\.)?gz$/i
      Misc.unzip(dataset, deploy)
    else
      Open.ln_s dataset, deploy
    end

    if deploy.glob("*").length == 1 && File.directory?(dir = deploy.glob("*").first)
      dir.glob("*").each do |file|
        Open.ln_s file, deploy
      end
      sleep 1
    end

    spacy_lang = "es_core_news_sm"
    CMD.cmd(:spacy, "download #{spacy_lang}")
    Open.write params, <<-EOF
#----- Possible modes of operation -----------------------------------------------------------------------------------------------------------------#
# training mode (from scratch): set train_model to True, and use_pretrained_model to False (if training from scratch).                        #
#				 				Must have train and valid sets in the dataset_text_folder, and test and deployment sets are optional.               #
# training mode (from pretrained model): set train_model to True, and use_pretrained_model to True (if training from a pretrained model).     #
#				 						 Must have train and valid sets in the dataset_text_folder, and test and deployment sets are optional.      #
# prediction mode (using pretrained model): set train_model to False, and use_pretrained_model to True.                                       #
#											Must have either a test set or a deployment set.                                                        #
# NOTE: Whenever use_pretrained_model is set to True, pretrained_model_folder must be set to the folder containing the pretrained model to use, and #
# 		model.ckpt, dataset.pickle and parameters.ini must exist in the same folder as the checkpoint file.                                         #
#---------------------------------------------------------------------------------------------------------------------------------------------------#

[mode]
# At least one of use_pretrained_model and train_model must be set to True.
train_model = False
use_pretrained_model = True
pretrained_model_folder = #{File.expand_path model}

[dataset]
dataset_text_folder = #{File.expand_path files_dir}

# main_evaluation_mode should be either 'conll', 'bio', 'token', or 'binary'. ('conll' is entity-based)
# It determines which metric to use for early stopping, displaying during training, and plotting F1-score vs. epoch.
main_evaluation_mode = conll

output_folder = #{File.expand_path output}

#---------------------------------------------------------------------------------------------------------------------#
# The parameters below are for advanced users. Their default values should yield good performance in most cases.      #
#---------------------------------------------------------------------------------------------------------------------#

[ann]
use_character_lstm = True
character_embedding_dimension = 25
character_lstm_hidden_state_dimension = 25

use_pos = True

# In order to use random initialization instead, set token_pretrained_embedding_filepath to empty string, as below:
# token_pretrained_embedding_filepath =
token_pretrained_embedding_filepath = #{File.expand_path embeddings}
token_embedding_dimension = 300
token_lstm_hidden_state_dimension = 300

use_crf = True

[training]
patience = 10
maximum_number_of_epochs = 100

# optimizer should be either 'sgd', 'adam', or 'adadelta'
optimizer = sgd
learning_rate = 0.005
# gradients will be clipped above |gradient_clipping_value| and below -|gradient_clipping_value|, if gradient_clipping_value is non-zero
# (set to 0 to disable gradient clipping)
gradient_clipping_value = 5.0

# dropout_rate should be between 0 and 1
dropout_rate = 0.5

# Upper bound on the number of CPU threads NeuroNER will use
number_of_cpu_threads = 8

# Upper bound on the number of GPU NeuroNER will use
# If number_of_gpus > 0, you need to have installed tensorflow-gpu
number_of_gpus = 0

[advanced]
experiment_name = #{clean_name}

# tagging_format should be either 'bioes' or 'bio'
tagging_format = bioes

# tokenizer should be either 'spacy' or 'stanford'. The tokenizer is only used when the original data is provided only in BRAT format.
# - 'spacy' refers to spaCy (https://spacy.io). To install spacy: pip install -U spacy
# - 'stanford' refers to Stanford CoreNLP (https://stanfordnlp.github.io/CoreNLP/). Stanford CoreNLP is written in Java: to use it one has to start a
#              Stanford CoreNLP server, which can tokenize sentences given on the fly. Stanford CoreNLP is portable, which means that it can be run
#              without any installation.
#              To download Stanford CoreNLP: https://stanfordnlp.github.io/CoreNLP/download.html
#              To run Stanford CoreNLP, execute in the terminal: `java -mx4g -cp "*" edu.stanford.nlp.pipeline.StanfordCoreNLPServer -port 9000 -timeout 50000`
#              By default Stanford CoreNLP is in English. To use it in other languages, see: https://stanfordnlp.github.io/CoreNLP/human-languages.html
#              Stanford CoreNLP 3.6.0 and higher requires Java 8. We have tested NeuroNER with Stanford CoreNLP 3.6.0.
tokenizer = spacy
# spacylanguage should be either 'de' (German), 'en' (English) or 'fr' (French). (https://spacy.io/docs/api/language-models)
# To install the spaCy language: `python -m spacy.de.download`; or `python -m spacy.en.download`; or `python -m spacy.fr.download`
spacylanguage = #{spacy_lang}

# If remap_unknown_tokens is set to True, map to UNK any token that hasn't been seen in neither the training set nor the pre-trained token embeddings.
remap_unknown_tokens_to_unk = True

# If load_only_pretrained_token_embeddings is set to True, then token embeddings will only be loaded if it exists in token_pretrained_embedding_filepath
# or in pretrained_model_checkpoint_filepath, even for the training set.
load_only_pretrained_token_embeddings = False

# If load_all_pretrained_token_embeddings is set to True, then all pretrained token embeddings will be loaded even for the tokens that do not appear in the dataset.
load_all_pretrained_token_embeddings = False

# If check_for_lowercase is set to True, the lowercased version of each token will also be checked when loading the pretrained embeddings.
# For example, if the token 'Boston' does not exist in the pretrained embeddings, then it is mapped to the embedding of its lowercased version 'boston',
# if it exists among the pretrained embeddings.
check_for_lowercase = True

# If check_for_digits_replaced_with_zeros is set to True, each token with digits replaced with zeros will also be checked when loading pretrained embeddings.
# For example, if the token '123-456-7890' does not exist in the pretrained embeddings, then it is mapped to the embedding of '000-000-0000',
# if it exists among the pretrained embeddings.
# If both check_for_lowercase and check_for_digits_replaced_with_zeros are set to True, then the lowercased version is checked before the digit-zeroed version.
check_for_digits_replaced_with_zeros = True

# If freeze_token_embeddings is set to True, token embedding will remain frozen (not be trained).
freeze_token_embeddings = False

freeze_pos = False

# If debug is set to True, only 200 lines will be loaded for each split of the dataset.
debug = False
verbose = False

# plot_format specifies the format of the plots generated by NeuroNER. It should be either 'png' or 'pdf'.
plot_format = pdf

# specify which layers to reload from the pretrained model
reload_character_embeddings = True
reload_character_lstm = True
reload_token_embeddings = True
reload_token_lstm = True
reload_feedforward = True
reload_crf = True

parameters_filepath = #{params}
    EOF

    Misc.in_dir(Rbbt.software.opt["TeMU-NeuroNER"].find) do
      CMD.cmd_log("python #{Rbbt.software.opt["TeMU-NeuroNER/main.py"].find} --parameters_filepath '#{params}'")
    end

    tsv = TSV.setup({}, :key_field => "ID", :fields => ["Document", "Literal", "Type", "Start", "End"], :type => :list)
    output.glob("*/brat/deploy/*.ann").each do |file|
      name = File.basename(file).sub(/\.ann$/,'')
      TSV.traverse file, :type => :line, :into => tsv do |line|
        id, type_pos, literal = line.split("\t")
        type, start, eend = type_pos.split(" ")
        id = [name, type, start, eend] * ":"
        values = [name, literal, type, start, eend]
        [id, values]
      end
    end
    tsv
  end

  export :neuro_ner
end

#require 'TeMU/tasks/basic.rb'

#require 'rbbt/knowledge_base/TeMU'
#require 'rbbt/entity/TeMU'

