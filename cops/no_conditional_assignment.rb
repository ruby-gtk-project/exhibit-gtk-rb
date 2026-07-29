# frozen_string_literal: true

# Bans assigning an `if`/`case` (or ternary) expression to a variable or via a
# setter:
#
#   color = if dark then GREY else WHITE end        # NO
#   obj.scheme = case name; when ...; end           # NO
#   x = cond ? a : b                                 # NO (ternary is an `if`)
#
# The conditional must make the assignment itself, inside each branch, so the
# assignment target isn't hidden behind a multi-line expression:
#
#   if dark                                          # YES
#     color = GREY
#   else
#     color = WHITE
#   end
module RuboCop
  module Cop
    module Local
      class NoConditionalAssignment < Base
        MSG = "Do not assign an `if`/`case` expression; make the assignment " \
              "inside each branch."

        def on_lvasgn(node)
          check(node.children.last)
        end
        alias on_ivasgn on_lvasgn
        alias on_cvasgn on_lvasgn
        alias on_gvasgn on_lvasgn

        def on_casgn(node)
          check(node.children.last)
        end

        def on_send(node)
          if node.assignment_method?
            check(node.arguments.last)
          end
        end

        private

        def check(rhs)
          if rhs.is_a?(RuboCop::AST::Node) && %i[if case].include?(rhs.type)
            add_offense(rhs)
          end
        end
      end
    end
  end
end
