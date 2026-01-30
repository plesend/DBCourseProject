
-- для менеджера
CREATE SYNONYM manager_user.Musicians FOR admin_user.Musicians;
CREATE SYNONYM manager_user.Albums  FOR admin_user.Albums;
CREATE SYNONYM manager_user.Music   FOR admin_user.Music;
CREATE SYNONYM manager_user.Awards  FOR admin_user.Awards;
CREATE SYNONYM manager_user.Nominants FOR admin_user.Nominees;
CREATE SYNONYM manager_user.Winners FOR admin_user.Winners;
CREATE SYNONYM manager_user.Votes FOR admin_user.Votes;
CREATE SYNONYM manager_user.pkg_manager FOR admin_user.pkg_manager;

--for guest
CREATE SYNONYM guest_user.Musicians FOR admin_user.Musicians;
CREATE SYNONYM guest_user.Albums  FOR admin_user.Albums;
CREATE SYNONYM guest_user.Music   FOR admin_user.Music;
CREATE SYNONYM guest_user.Awards  FOR admin_user.Awards;
CREATE SYNONYM guest_user.Winners FOR admin_user.Winners;
CREATE SYNONYM guest_user.Nominants FOR admin_user.Nominants;
CREATE SYNONYM guest_user.Votes FOR admin_user.Votes;
CREATE SYNONYM guest_user.pkg_guest FOR admin_user.pkg_guest;

CREATE SYNONYM guest_user.trg_vote_insert FOR admin_user.trg_vote_insert;

