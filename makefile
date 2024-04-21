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

X=

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

$(DP)/fullGX%m10$X.mindex: $(MS)/mstrip.exe $(MS)/mtokenize.exe $(MS)/minvert.exe | $(DP)
	time bunzip2 -ck $(DC)/GX??$(*)/*.bz2 | $(MS)/mstrip.exe | $(MS)/mtokenize.exe | $(MS)/minvert.exe > $(DP)/fullGX$(*)m10$X.mindex

$(DI)/fullGX$X.mindex: $(MS)/mmerge.exe $(DP)/fullGX0m10$X.mindex $(DP)/fullGX1m10$X.mindex $(DP)/fullGX2m10$X.mindex $(DP)/fullGX3m10$X.mindex $(DP)/fullGX4m10$X.mindex \
		 $(DP)/fullGX5m10$X.mindex $(DP)/fullGX6m10$X.mindex $(DP)/fullGX7m10$X.mindex $(DP)/fullGX8m10$X.mindex $(DP)/fullGX9m10$X.mindex | $(DI)
	time $(MS)/mmerge.exe $(DP)/fullGX*m10$X.mindex > $(DI)/fullGX$X.mindex

$(DI)/fullGX$X.mindex.meta: $(DI)/fullGX$X.mindex $(MS)/mencode.exe
	time $(MS)/mencode.exe $(DI)/fullGX$X.mindex

index: $(DI)/fullGX$X.mindex.meta

# ------------------ QUERY ------------------
$(DR): | $(DD)
	echo "***** creating directory $(DR)"; mkdir $(DR)

$(DP)/query-base.txt: $(DO)/topics.[78]*
	cat $(DO)/topics.[78]* | awk '{if($$2=="Number:")n=$$3; if($$1=="<title>"){$$1="";q=$$0} if($$0=="</top>")print n";"q}' > $(DP)/query-base.txt

$(DP)/query-tdesc.txt: $(DO)/topics.[78]*
	cat $(DO)/topics.[78]* | awk 'BEGIN{k=1} {if($$2=="Number:")n=$$3; if($$1=="<title>"){$$1="";q=$$0} if(k==1&&substr($$0,1,1)!="<")q=q" "$$0; if($$1=="<narr>")k=0; if($$0=="</top>"){k=1;print n";"q}}' > $(DP)/query-tdesc.txt

$(DP)/query-all.txt: $(DO)/topics.[78]*
	cat $(DO)/topics.[78]* | awk '{if($$2=="Number:")n=$$3; if($$1=="<title>"){$$1="";q=$$0} if(substr($$0,1,1)!="<")q=q" "$$0; if($$0=="</top>")print n";"q}' > $(DP)/query-all.txt

$(DR)/trec-fullGX$X-%.tsv: $(DP)/query-%.txt $(DI)/fullGX$X.mindex $(MS)/mtokenize.exe $(MS)/msearch.exe | $(DR)
	time cat $(DP)/query-$(*).txt | $(MS)/mtokenize.exe -q | $(MS)/msearch.exe -k1000 $(DI)/fullGX$X.mindex | awk '{$$5=$$5"\tmtextsearch-base"; $$2="Q0\t"$$2; print}' > $(DR)/trec-fullGX$X-$(*).tsv

.PRECIOUS: $(DR)/trec-fullGX$X-%.tsv

query-%: $(DR)/trec-fullGX$X-%.tsv
	
query: query-base

# ------------------ EVAL ------------------
$(TE)/trec_eval:
	$(MAKE) -C $(TE)

eval-%: $(DR)/trec-fullGX$X-%.tsv $(TE)/trec_eval
	$(TE)/trec_eval -m num_q -m P.10 -m map -m ndcg -m ndcg_cut.10 $(DO)/qrels.701-850.txt $(DR)/trec-fullGX$X-$(*).tsv

eval: eval-base

