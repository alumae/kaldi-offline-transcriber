# /usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import print_function

import sys
import os
import argparse
import unicodedata
import itertools
import string
import pdb
from pynini import *
import pytest

input_chars = list(u" 0123456789-+/_.:'~,")
input_chars.extend(list(u"abcdefghijklmnoprsštuvwõõäöüxyzž"))
input_chars.extend(u"ćçčĉø")
input_chars.extend([c.upper() for c in input_chars])

sigma_star = string_map(input_chars, input_token_type="utf8", output_token_type="utf8").closure().optimize()

digits_2_to_9 = {
  "kaks" : "2",
  "kolm" : "3",
  "neli" : "4",
  "viis" : "5",
  "kuus" : "6",
  "seitse" : "7",
  "kaheksa" : "8",
  "üheksa" : "9"}
  
numbers_10_to_19_nom = {
  "kümme" : "10",
  "üksteist" : "11",
  "kaksteist" : "12",
  "kolmteist" : "13",
  "neliteist" : "14",
  "viisteist" : "15",
  "kuusteist" : "16",
  "seitseteist" : "17",
  "kaheksateist" : "18",
  "üheksateist" : "19"
}

# Genitive

digits_2_to_9_gen = {
  "kahe" : "2",
  "kolme" : "3",
  "nelja" : "4",
  "viie" : "5",
  "kuue" : "6",
  "seitsme" : "7",
  "kaheksa" : "8",
  "üheksa" : "9"}
  
numbers_10_to_19_gen = {
  "kümne" : "10",
  "üheteistkümne" : "11",
  "kaheteistkümne" : "12",
  "kolmeteistkümne" : "13",
  "neljateistkümne" : "14",
  "viieteistkümne" : "15",
  "kuueteistkümne" : "16",
  "seitsmeteistkümne" : "17",
  "kaheksateistkümne" : "18",
  "üheksateistkümne" : "19"
}

digits_2_to_9_ord = {
  "teine" : "2",
  "kolmas" : "3",
  "neljas" : "4",
  "viies" : "5",
  "kuues" : "6",
  "seitsmes" : "7",
  "kaheksas" : "8",
  "üheksas" : "9"}

nom_to_gen = {
  "üks" : "ühe",
  "kaks" : "kahe",
  "kolm" : "kolme",
  "neli" : "nelja",
  "viis" : "viie",
  "kuus" : "kuue",
  "seitse" : "seitsme",
  "kaheksa" : "kaheksa",
  "üheksa" : "üheksa",
  "kümme" : "kümne",
  "kümmend" : "kümne",
  "üksteist" : "üheteistkümne",
  "kaksteist" : "kaheteistkümne",
  "kolmteist" : "kolmeteistkümne",
  "neliteist" : "neljateistkümne",
  "viisteist" : "viieteistkümne",
  "kuusteist" : "kuueteistkümne",
  "seitseteist" : "sitsmeteistkümne",
  "kaheksateist" : "kaheksateistkümne",
  "üheksateist" : "üheksateistkümne",
  
  "sada" : "saja",
  "tuhat" : "tuhande"
}
  
gen_to_ord_specials = {
  "ühe" : "esimene",
  "kahe" : "teine",
  "kolme" :  "kolmas",
}

gen_to_ord_gen_specials = {
  "ühe" : "esimese",
  "kahe" : "teise",
  "kolme" :  "kolmanda",
}

  
@pytest.fixture(scope="module") 
def words2num_fst():
    
  left_break = a("[BOS]") | a(" ") 
  right_break = a("[EOS]") | a(" ")
  
  t_10_to_19 = string_map(numbers_10_to_19_nom, input_token_type="utf8", output_token_type="utf8").optimize()
  t_2_to_9 = string_map(digits_2_to_9, input_token_type="utf8", output_token_type="utf8").optimize()
  t_1_to_9 = t_2_to_9 | t("üks", "1", input_token_type="utf8", output_token_type="utf8")
    
  t_tens_cont =  t_2_to_9 + t("kümmend", "", input_token_type="utf8", output_token_type="utf8")
  
  t_tens = t_tens_cont + t("", "0")
  
  t_20_to_99 = t_tens | (t_tens_cont + t(" ", "") + t_1_to_9)
  
  t_10_to_99 = t_10_to_19 | t_20_to_99
  
  t_100_to_999 = (t("üks", "1",  input_token_type="utf8") | t("", "1") | t_2_to_9 ) + t("sada", "") + \
    ( 
      t("", "00") | 
      (t(" ", "0", weight=-1) + (t_1_to_9)) | 
      (t(" ", "", weight=-2) + t_10_to_99) 
    )
  
  
  t_1000_to_9999 = (t("üks ", "1",  input_token_type="utf8") | t("", "1") | (t_2_to_9 + t(" ", ""))) + t("tuhat", "") + \
    (
      (t(" ", "", ) + t_100_to_999) | 
      (t(" ", "0") + t_10_to_99) |
      (t(" ", "00") + t_1_to_9)  |
      t("", "000")
    )
  
  t_10_to_9999 = (t_10_to_19 | t_20_to_99 | t_100_to_999 | t_1000_to_9999).optimize()
  
  t_0_to_9 = t("null", "0") | t_1_to_9
  t_0_to_99 = t_0_to_9 | t_10_to_19 | t_20_to_99
  t_0_to_9999 = t_0_to_9 | t_10_to_9999
  
  t_fractional_part = t(" koma ", ",") + \
    (
      t_0_to_9999 | 
      (t("null", "0", weight=-1) + (t(" ", "", weight=-1) + t_0_to_9).plus)
    )
      
  t_fraction = t_0_to_9999 + t_fractional_part
  
  
  # Genitive
  t_gen_to_nom = cdrewrite(string_map(nom_to_gen, input_token_type="utf8", output_token_type="utf8").invert(), "", "", sigma_star) 
  t_10_to_9999_gen = t_gen_to_nom * t_10_to_9999
  t_fraction_gen = t_gen_to_nom * t_fraction

  # Other inflections
  t_10_to_9999_infl = t_10_to_9999_gen + (t("", "-") + union(u"le", u"l", u"ni", u"ga", u"lt", u"st", u"na", u"sse"))
  
  # Ordinal nominative
  t_ord_to_gen = string_map(gen_to_ord_specials, input_token_type="utf8", output_token_type="utf8").invert() | t("s", "")
  t_10_to_9999_ord = (sigma_star + t_ord_to_gen) * t_10_to_9999_gen + t("", ".")
  
  # Ordinal genitive
  t_ord_gen_to_gen = string_map(gen_to_ord_gen_specials, input_token_type="utf8", output_token_type="utf8").invert() | t("nda", "")
  t_10_to_9999_ord_gen = (sigma_star + t_ord_gen_to_gen) * t_10_to_9999_gen + t("", ".")
  
  # Ordinal other inflections
  t_10_to_9999_ord_infl = t_10_to_9999_ord_gen + (t("l", "") |  (t("", "-") + union(u"le", u"ni", u"ga", u"lt", u"st", u"na", u"sse", u"te", u"tele", u"teni", u"tega", u"telt", u"test", u"tesse")))
   
  transforms = [
    cdrewrite(t_fraction, left_break, right_break, sigma_star),
    cdrewrite(t_10_to_9999, left_break, right_break, sigma_star),

    cdrewrite(t_10_to_9999_infl, left_break, right_break, sigma_star),
    cdrewrite(t_fraction_gen, left_break, right_break, sigma_star),
    cdrewrite(t_10_to_9999_ord, left_break, right_break, sigma_star),
    cdrewrite(t_10_to_9999_ord_gen, left_break, right_break, sigma_star),
    cdrewrite(t_10_to_9999_ord_infl, left_break, right_break, sigma_star),
    cdrewrite(t_10_to_9999_gen, left_break, right_break, sigma_star),
  ]
  
  result = sigma_star
  for transform in transforms:
    result = result * transform
  
  return result

def words2num(fst, text):
  text_fsa = acceptor(text.encode("utf8"), token_type="utf8")
  result = text_fsa * fst
  result = shortestpath(result)
  try:
    return result.stringify(token_type="utf8")
  except:
    print("Failed to convert sentence", file=sys.stderr)
    return text

if __name__ == '__main__':
  words2num_fst = words2num_fst()
  while 1:    
    l = sys.stdin.readline()
    if not l: break
    print(words2num(words2num_fst, l.strip()))

      
def test_simple(words2num_fst):    
  assert words2num(words2num_fst, "see on üheksateist protsenti suurem") == "see on 19 protsenti suurem"
  assert words2num(words2num_fst, "see on kakskümmend protsenti suurem") == "see on 20 protsenti suurem"
  assert words2num(words2num_fst, "see on kakskümmend üks protsenti suurem") == "see on 21 protsenti suurem"
  assert words2num(words2num_fst, "see on sada protsenti") == "see on 100 protsenti"
  assert words2num(words2num_fst, "see on sada kümme protsenti") == "see on 110 protsenti"
  assert words2num(words2num_fst, "see on sada üks protsenti") == "see on 101 protsenti"
  assert words2num(words2num_fst, "see on tuhat korda") == "see on 1000 korda"
  assert words2num(words2num_fst, "aastal tuhat üheksasada kaheksakümmend") == "aastal 1980"
  assert words2num(words2num_fst, "kolm koma neliteist protsenti") == "3,14 protsenti"
  assert words2num(words2num_fst, "kolm koma null üks protsenti") == "3,01 protsenti"
  assert words2num(words2num_fst, "viiskümmend koma null null kaheksa kaks protsenti") == "50,0082 protsenti"
    

def test_inflections(words2num_fst):
  # inflections
  assert words2num(words2num_fst, "see on kahe või isegi kaheteistkümne protsendi võrra suurem") == "see on kahe või isegi 12 protsendi võrra suurem"
  assert words2num(words2num_fst, "see on kolmeteistkümne võrra suurem") == "see on 13 võrra suurem"  
  assert words2num(words2num_fst, "see on saja võrra suurem") == "see on 100 võrra suurem"  
  assert words2num(words2num_fst, "see on saja ühe võrra suurem") == "see on 101 võrra suurem"
  assert words2num(words2num_fst, "see on kahekümne protsendi võrra suurem") == "see on 20 protsendi võrra suurem"
  assert words2num(words2num_fst, "see on kolme koma kahe protsendi võrra suurem") == "see on 3,2 protsendi võrra suurem"
  assert words2num(words2num_fst, "see on kolme koma null kahe protsendi võrra suurem") == "see on 3,02 protsendi võrra suurem"
  
def test_ordinals(words2num_fst):  
  # ordinals
  assert words2num(words2num_fst, "see on kolmeteistkümnes kord") == "see on 13. kord"
  assert words2num(words2num_fst, "Tallinna neljakümne esimene kool") == "Tallinna 41. kool"
  assert words2num(words2num_fst, "see juhtus kahe tuhandenda aasta suvel") == "see juhtus 2000. aasta suvel"
  assert words2num(words2num_fst, "see juhtus kahe tuhande esimesel aastal") == "see juhtus 2001. aastal"
  assert words2num(words2num_fst, "see juhtus kaheksakümnendate aastate paiku") == "see juhtus 80.-te aastate paiku"
  
def  test_complex_inflections(words2num_fst):
  # more complex inflections
  assert words2num(words2num_fst, "see kasvas kaheteistkümnele protsendile") == "see kasvas 12-le protsendile"
  assert words2num(words2num_fst, "see kasvas sajale protsendile") == "see kasvas 100-le protsendile"
  assert words2num(words2num_fst, "see kasvas sajandi protsendile") == "see kasvas sajandi protsendile"
  assert words2num(words2num_fst, "see kasvas saja ühele protsendile") == "see kasvas 101-le protsendile"

def  test_invalid_chars(words2num_fst):
  assert words2num(words2num_fst, "€¨€½|") == "€¨€½|"
