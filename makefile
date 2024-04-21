# to run things in parallel run: make -j #

all:
	echo "usage: make [index|query|eval]"

# ------------------ common elements ------------------

SHELL = /bin/bash

DD = data
DC = data/corpus
DO = data/original
DP = data/processed
DI = data/index
DR = data/results

MS = mtextsearch
TE = trec_eval
SW = stopwords/en

ifneq ($(origin LANG),undefined)
  $(error ENV LANG - Internationalization breaks corpus generation)
endif

.PRECIOUS: $(MS)/%.exe

$(MS)/%.exe: $(MS)/src/*
	$(MAKE) -C $(MS) $(*).exe

# ------------------ INDEX ------------------
$(DP): | $(DD)
	echo "***** creating directory $(DP)"; mkdir $(DP)

$(DI): | $(DD)
	echo "***** creating directory $(DI)"; mkdir $(DI)

$(DP)/fullGX%m10.mindex: $(MS)/mstrip.exe $(MS)/mtokenize.exe $(MS)/minvert.exe | $(DP)
	time bunzip2 -ck $(DC)/GX??$(*)/*.bz2 | $(MS)/mstrip.exe | $(MS)/mtokenize.exe | $(MS)/minvert.exe > $(DP)/fullGX$(*)m10.mindex

$(DI)/fullGX.mindex: $(MS)/mmerge.exe $(DP)/fullGX0m10.mindex $(DP)/fullGX1m10.mindex $(DP)/fullGX2m10.mindex $(DP)/fullGX3m10.mindex $(DP)/fullGX4m10.mindex \
		 $(DP)/fullGX5m10.mindex $(DP)/fullGX6m10.mindex $(DP)/fullGX7m10.mindex $(DP)/fullGX8m10.mindex $(DP)/fullGX9m10.mindex | $(DI)
	time $(MS)/mmerge.exe $(DP)/fullGX*m10.mindex > $(DI)/fullGX.mindex

$(DI)/fullGX.mindex.meta: $(DI)/fullGX.mindex $(MS)/mencode.exe
	time $(MS)/mencode.exe $(DI)/fullGX.mindex

index: $(DI)/fullGX.mindex.meta

# ------------------ QUERY ------------------
$(DR): | $(DD)
	echo "***** creating directory $(DR)"; mkdir $(DR)

$(DP)/query-base.txt: $(DO)/topics.[78]*
	cat $(DO)/topics.[78]* | awk '{if ($$2=="Number:") n=$$3; if ($$1=="<title>") {$$1=""; q=$$0} if ($$0=="</top>") print n ";" q;}' > $(DP)/query-base.txt

$(DR)/trec-fullGX-base.tsv: $(DP)/query-base.txt $(DI)/fullGX.mindex $(MS)/mtokenize.exe $(MS)/msearch.exe | $(DR)
	time cat $(DP)/query-base.txt | $(MS)/mtokenize.exe -q | $(MS)/msearch.exe -k1000 $(DI)/fullGX.mindex | awk '{$$5=$$5"\tmtextsearch-base"; $$2="Q0\t"$$2; print}' > $(DR)/trec-fullGX-base.tsv

query: $(DR)/trec-fullGX-base.tsv

# ------------------ EVAL ------------------
$(TE)/trec_eval:
	$(MAKE) -C $(TE)

eval: $(DR)/trec-fullGX-base.tsv $(TE)/trec_eval
	$(TE)/trec_eval -m num_q -m P.10 -m map -m ndcg -m ndcg_cut.10 $(DO)/qrels.701-850.txt $(DR)/trec-fullGX-base.tsv

