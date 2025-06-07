class ZprotectPolicy < ApplicationPolicy
  def access?
    # Allow access if user is an agent or admin in the current account
    return false unless user.present? && account.present?

    # Check if user has agent or admin role in this account
    account_user.present? && %w[agent administrator].include?(account_user.role)
  end

  def orders?
    access?
  end

  def cancel_order?
    # Only agents and admins can cancel orders
    access? && %w[agent administrator].include?(account_user.role)
  end

  def refund_order?
    # Only agents and admins can process refunds
    access? && %w[agent administrator].include?(account_user.role)
  end

  def health?
    access?
  end

  def invalidate_cache?
    access?
  end

  private

  def account_user_role
    account_user&.role
  end
end
