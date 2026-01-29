-- Esquema inicial mínimo para o projeto V10

CREATE TABLE IF NOT EXISTS motoristas (
  id text primary key,
  nome text not null,
  telefone text,
  email text,
  placa_veiculo text,
  esta_online boolean default false,
  aprovado boolean default false,
  latitude double precision,
  longitude double precision,
  criado_em timestamptz default now()
);

CREATE TABLE IF NOT EXISTS pedidos (
  id text primary key,
  nome_cliente text not null,
  telefone_cliente text,
  endereco text not null,
  endereco_latitude double precision,
  endereco_longitude double precision,
  motorista_id text references motoristas(id),
  observacoes text,
  status text default 'pendente',
  valor numeric,
  criado_em timestamptz default now()
);

CREATE TABLE IF NOT EXISTS mensagens (
  id text primary key,
  remetente_id text not null,
  destinatario_id text not null,
  texto text not null,
  lida boolean default false,
  criado_em timestamptz default now()
);
