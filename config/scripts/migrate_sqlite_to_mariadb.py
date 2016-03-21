#!/usr/bin/python

from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base


def make_session(connection_string):
    engine = create_engine(connection_string, echo=True,
                           encoding='utf-8', convert_unicode=True)
    Session = sessionmaker(bind=engine)
    return Session(), engine


def pull_data(from_db, to_db, tables):
    source, source_engine = make_session(from_db)
    source_meta = MetaData(bind=source_engine)
    destination, dest_engine = make_session(to_db)

    for table_name in tables:
        print 'Processing', table_name
        print 'Pulling schema from source server'
        table = Table(table_name, source_meta, autoload=True)
        print 'Creating table on destination server'
        table.metadata.create_all(dest_engine, checkfirst=True)
        NewRecord = quick_mapper(table)
        columns = table.columns.keys()
        print 'Transferring records'
        for record in source.query(table).all():
            data = dict(
                [(str(column), getattr(record, column)) for column in columns]
            )
            destination.merge(NewRecord(**data))
    print 'Committing changes'
    destination.commit()


def quick_mapper(table):
    Base = declarative_base()

    class GenericMapper(Base):
        __table__ = table

    return GenericMapper


if __name__ == '__main__':
    import sys
    import os
    sys.path.append(os.path.abspath("/var/www/managesf/"))
    from managesf import config as managesf_conf
    sys.path.append(os.path.abspath("/var/www/cauth/"))
    from cauth import config as cauth_conf

    # Default values, should not be valid for all deployments
    MANAGESF_SQLITE_PATH_URL = 'sqlite:////var/lib/managesf/users.db'
    CAUTH_SQLITE_PATH_URL = 'sqlite:////var/lib/cauth/state_mapping.db'

    # pull local users data from managesf
    pull_data(MANAGESF_SQLITE_PATH_URL,
              managesf_conf.sqlalchemy['url'],
              'users')
    #pull auth mappings date from cauth
    pull_data(CAUTH_SQLITE_PATH_URL,
              cauth_conf.sqlalchemy['url'],
              'auth_mapping')
