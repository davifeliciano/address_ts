CREATE TEXT SEARCH DICTIONARY address_syn_dict (
    TEMPLATE = synonym,
    SYNONYMS = address_syn_dict
);

CREATE TEXT SEARCH CONFIGURATION address (
    COPY = portuguese
);

ALTER TEXT SEARCH CONFIGURATION address
ALTER MAPPING FOR asciiword WITH address_syn_dict, portuguese_stem;

CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE OR REPLACE FUNCTION remove_leading_zeroes(text)
RETURNS text LANGUAGE SQL IMMUTABLE AS $$
    SELECT regexp_replace($1, '(^|\s)0+(\d+(?:$|\s))', '\1\2', 'g')
$$;

CREATE OR REPLACE FUNCTION remove_punctuation(text)
RETURNS text LANGUAGE SQL IMMUTABLE AS $$
    SELECT regexp_replace(
        regexp_replace(
            $1,
            '(?<![\d.,])[.,]+(?![\d.,])', ' ', 'g' -- remove dots and commas not enclosed by digits
        ),
        '(?![\.,"])[[:punct:]]', ' ', 'g' -- remove all punctuation except for dots, commas and double quotes
    )
$$;

CREATE OR REPLACE FUNCTION filter_text(text)
RETURNS text LANGUAGE SQL IMMUTABLE AS $$
    SELECT remove_leading_zeroes(remove_punctuation(unaccent(coalesce($1, ''))))
$$;

CREATE OR REPLACE FUNCTION to_address_tsvector(text)
RETURNS tsvector LANGUAGE SQL IMMUTABLE AS $$
    SELECT to_tsvector('address', filter_text($1))
$$;

CREATE TABLE cadastrofiscal (
    cfdf text,
    cnpj text,
    razao_social text,
    fantasia text,
    data_inscricao text,
    descricao_situacao text,
    endereco text,
    bairro text,
    cidade text,
    uf text,
    cep text,
    iptu text,
    descrição_tipo text,
    nomeregimeiss text,
    nomeregimeicms text,
    cnae_icms text,
    descricao_icms text,
    cnae_iss text,
    descricao_iss text
);

CREATE TABLE lotesimplantados (
    ct_ciu text,
    ct_origem integer,
    lt_endereco text,
    lt_setor text,
    lt_quadra text,
    lt_conjunto text,
    lt_lote text,
    lt_nome text,
    lt_cep text,
    lt_ra integer,
    st_area_sh numeric,
    st_length numeric
);

CREATE TABLE ras (
    numero integer,
    nome text
);

\copy cadastrofiscal FROM '/csv/cadastrofiscal.csv' WITH CSV HEADER;
\copy lotesimplantados FROM '/csv/lotesimplantados.csv' WITH CSV HEADER;
\copy ras FROM '/csv/ras.csv' WITH CSV HEADER;

ALTER TABLE cadastrofiscal
ADD COLUMN address_tsvector_weighted tsvector
GENERATED ALWAYS AS (
    setweight(to_address_tsvector(endereco), 'A') ||
    setweight(to_address_tsvector(bairro), 'B')   ||
    setweight(to_address_tsvector(cidade), 'C')   ||
    setweight(to_address_tsvector(uf), 'C')
) STORED;

ALTER TABLE cadastrofiscal
ADD COLUMN address_tsvector tsvector
GENERATED ALWAYS AS (
    to_address_tsvector(
        coalesce(endereco, '') || ' ' ||
        coalesce(bairro, '')   || ' ' ||
        coalesce(cidade, '')   || ' ' ||
        coalesce(uf, '')
    )
) STORED;

CREATE INDEX cf_ts_weighted_idx ON cadastrofiscal USING GIN (address_tsvector_weighted);
CREATE INDEX cf_ts_idx ON cadastrofiscal USING GIN (address_tsvector);

ALTER TABLE lotesimplantados
ADD COLUMN address_tsvector tsvector
GENERATED ALWAYS AS (
    to_address_tsvector(
        coalesce(lt_endereco, '') || ' ' ||
        coalesce(lt_setor, '')    || ' ' ||
        coalesce(lt_quadra, '')   || ' ' ||
        coalesce(lt_conjunto, '') || ' ' ||
        coalesce(lt_lote, '')     || ' ' ||
        coalesce(lt_nome, '')
    )
) STORED;

CREATE INDEX li_ts_idx ON lotesimplantados USING GIN (address_tsvector);
