"""add_cloud_command_queue

Revision ID: ab12cd34ef56
Revises: dff83ffb277d
Create Date: 2026-04-14 17:35:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'ab12cd34ef56'
down_revision = 'dff83ffb277d'
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table('cloud_command_queue',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('vault_id', sa.String(), nullable=False),
    sa.Column('command_type', sa.String(), nullable=False),
    sa.Column('payload_json', sa.String(), nullable=True),
    sa.Column('status', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=True),
    sa.Column('delivered_at', sa.DateTime(), nullable=True),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_cloud_command_queue_id'), 'cloud_command_queue', ['id'], unique=False)
    op.create_index(op.f('ix_cloud_command_queue_status'), 'cloud_command_queue', ['status'], unique=False)
    op.create_index(op.f('ix_cloud_command_queue_vault_id'), 'cloud_command_queue', ['vault_id'], unique=False)

def downgrade() -> None:
    op.drop_index(op.f('ix_cloud_command_queue_vault_id'), table_name='cloud_command_queue')
    op.drop_index(op.f('ix_cloud_command_queue_status'), table_name='cloud_command_queue')
    op.drop_index(op.f('ix_cloud_command_queue_id'), table_name='cloud_command_queue')
    op.drop_table('cloud_command_queue')
