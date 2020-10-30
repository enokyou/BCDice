# frozen_string_literal: true

require "bcdice/base"

module BCDice
  module GameSystem
    class LogHorizon < Base
      # ゲームシステムの識別子
      ID = 'LogHorizon'

      # ゲームシステム名
      NAME = 'ログ・ホライズンTRPG'

      # ゲームシステム名の読みがな
      SORT_KEY = 'ろくほらいすんTRPG'

      # ダイスボットの使い方
      HELP_MESSAGE = <<~MESSAGETEXT
        ・判定(xLH±y>=z)
        　xD6の判定。クリティカル、ファンブルの自動判定を行います。
        　x：xに振るダイス数を入力。
        　±y：yに修正値を入力。±の計算に対応。省略可能。
          >=z：zに目標値を入力。±の計算に対応。省略可能。
        　例） 3LH　2LH>=8　3LH+1>=10
        ・消耗表(tCTx±y$z)
        　PCT 体力／ECT 気力／GCT 物品／CCT 金銭
        　x:CRを指定。
        　±y:修正値。＋と－の計算に対応。省略可能。
        　$z：＄を付けるとダイス目を z 固定。表の特定の値参照用に。省略可能。
        　例） PCT1　ECT2+1　GCT3-1　CCT3$5
        ・財宝表(tTRSx±y$)
        　CTRS 金銭／MTRS 魔法素材／ITRS 換金アイテム／OTRS そのほか／※HTRS ヒロイン／GTRS ゴブリン財宝表
        　x：CRを指定。省略時はダイス値 0 固定で修正値の表参照。《ゴールドフィンガー》使用時など。
        　±y：修正値。＋と－の計算に対応。省略可能。
        　$：＄を付けると財宝表のダイス目を7固定（1回分のプライズ用）。省略可能。
        　例） CTRS1　MTRS2+1　ITRS3-1　ITRS+27　CTRS3$
        ・パーソナリティタグ表(PTAG)
        ・交友表(KOYU)
        ・イースタル探索表(ESTLx±y$z)
        　x：CRを指定。省略時はダイス値 0 固定で修正値の表参照。
        　±y：修正値。＋と－の計算に対応。省略可能。
        　$z：＄を付けるとダイス目を z 固定。特定CRの表参照用に。省略可能。
        　例） ESTL1　ESTL+15　ESTL2+1$5　ESTL2-1$5
        ・プレフィックスドマジックアイテム効果表(MGRx) xはMGを指定。(LHZB1用)
        †楽器種別表(MIIx) xは楽器の種類(1～6を指定)、省略可能
        　1 打楽器１／2 鍵盤楽器／3 弦楽器１／4 弦楽器２／5 管楽器１／6 管楽器２
        ☆特殊消耗表(tSCTx±y$z)　消耗表と同様、ただしCRは省略可能。
        　ESCT ロデ研は爆発だ！／CSCT アルヴの呪いじゃ！
        ※攻撃命中箇所ランダム決定表(HLOC)
        ※PC名ランダム決定表(PCNM)
        ※ロデ研の新発明ランダム決定表(IATt)
          IATA 特徴A(メリット)／IATB 特徴B(デメリット)／IATL 見た目／IATT 種類
          tを省略すると全て表示。tにA/B/L/Tを任意の順で連結可能
          例）IAT　IATALT  IATABBLT  IATABL
        ※アキバの街で遭遇するトラブルランダム決定表(TIAS)
        ※廃棄児ランダム決定表(ABDC)
        †印は☆印は「イントゥ・ザ・セルデシア さらなるビルドの羽ばたき（１）」より、
        ☆印はセルデシア・ガゼット「できるかな66」Vol.1より、
        ※印は「実録・七面体工房スタッフ座談会(夏の陣)」より。利用法などはそちら参照。
        ・D66ダイスあり
      MESSAGETEXT

      register_prefix('\d+LH', 'PC', 'EC', 'GC', 'CC', 'CTR', 'MTR', 'ITR', 'OTR', 'HTR', 'GTR', 'IAT', 'TIAS', 'ABDC', 'MII', 'ESCT', 'CSCT', 'ESTL')

      def initialize(command)
        super(command)
        @enabled_d66 = true
        @d66_sort_type = D66SortType::NO_SORT
      end

      def eval_game_system_specific_command(command)
        getCheckRollDiceCommandResult(command) ||
          roll_consumption_table(command) ||
          roll_trasure_table(command) ||
          getInventionAttributeTextDiceCommandResult(command) ||
          getTroubleInAkibaStreetDiceCommandResult(command) ||
          getAbandonedChildDiceCommandResult(command) ||
          getMusicalInstrumentTypeDiceCommandResult(command) ||
          roll_eastal_exploration_table(command) ||
          roll_tables(command, self.class::TABLES)
      end

      private

      def getCheckRollDiceCommandResult(command)
        parser = CommandParser.new(/^\d+LH$/).allow_cmp_op(nil, :>=)

        parsed = parser.parse(command)
        unless parsed
          return nil
        end

        dice_count = parsed.command.to_i

        dice_list = @randomizer.roll_barabara(dice_count, 6)
        dice_total = dice_list.sum()
        total = dice_total + parsed.modify_number

        sequence = [
          "(#{parsed})",
          "#{dice_total}[#{dice_list.join(',')}]#{Format.modifier(parsed.modify_number)}",
          total,
          result_text(dice_count, dice_list, total, parsed),
        ].compact

        return sequence.join(" ＞ ")
      end

      def result_text(dice_count, dice_list, total, parsed)
        if dice_list.count(6) >= 2
          translate("LogHorizon.LH.critical")
        elsif dice_list.count(1) >= dice_count
          translate("LogHorizon.LH.fumble")
        elsif parsed.cmp_op.nil?
          nil
        elsif total >= parsed.target_number
          translate('success')
        else
          translate('failure')
        end
      end

      def getValue(text, defaultValue)
        return defaultValue if text.nil? || text.empty?

        ArithmeticEvaluator.eval(text)
      end

      ### 消耗表 ###
      def roll_consumption_table(command)
        m = /(P|E|G|C|ES|CS)CT(\d+)?([\+\-\d]+)?(?:\$(\d+))?/.match(command)
        return nil unless m

        table = construct_consumption_table(m[1])
        cr = m[2].to_i
        modifier = ArithmeticEvaluator.eval(m[3])
        table.fix_dice_value(m[4].to_i) if m[4]

        return table.roll(cr, modifier, @randomizer)
      end

      def construct_consumption_table(type)
        table =
          case type
          when "P"
            translate("LogHorizon.CT.PCT")
          when "E"
            translate("LogHorizon.CT.ECT")
          when "G"
            translate("LogHorizon.CT.GCT")
          when "C"
            translate("LogHorizon.CT.CCT")
          when "ES"
            translate("LogHorizon.CT.ESCT")
          when "CS"
            translate("LogHorizon.CT.CSCT")
          end

        ConsumptionTable.new(table[:name], table[:items])
      end

      # 消耗表
      class ConsumptionTable
        # @param name [String]
        # @param tables [Array[Hash{Integer => String}]]
        def initialize(name, tables)
          @name = name
          @tables = tables

          @dice_value = nil
        end

        # ダイスの値を固定する
        # @param dice [Integer]
        # @return [void]
        def fix_dice_value(dice)
          @dice_value = dice
        end

        def roll(cr, modifier, randomier)
          table_index = ((cr - 1) / 5).clamp(0, @tables.size - 1)
          items = @tables[table_index]

          @dice_value ||= randomier.roll_once(6)
          total = @dice_value + modifier

          chosen = items[total.clamp(0, 7)]

          "#{@name}(#{total}[#{@dice_value}])：#{chosen}"
        end
      end

      ### 財宝表 ###
      def roll_trasure_table(command)
        m = /(C|M|I|O|H|G)TRS(\d+)*([\+\-\d]+)?(\$)?/.match(command)
        return nil unless m

        type = m[1]
        table = construct_trasure_table(type)

        character_rank = m[2].to_i
        modifier = ArithmeticEvaluator.eval(m[3])
        return "#{command} ＞ CRを指定してください" if character_rank == 0 && modifier == 0

        table.fix_dice_value(7) if m[4]

        return table.roll(character_rank, modifier, @randomizer)
      end

      def construct_trasure_table(type)
        case type
        when "C"
          ExpansionTresureTable.new(translate("LogHorizon.TRS.CTRS.name"), CASH_TRESURE_RESULT_TABLE)
        when "M"
          ExpansionTresureTable.new(translate("LogHorizon.TRS.MTRS.name"), translate_with_hash_merge("LogHorizon.TRS.MTRS.items"))
        when "I"
          ExpansionTresureTable.new(translate("LogHorizon.TRS.ITRS.name"), translate_with_hash_merge("LogHorizon.TRS.ITRS.items"))
        when "O"
          ExpansionTresureTable.new(translate("LogHorizon.TRS.OTRS.name"), translate("LogHorizon.TRS.OTRS.items"))
        when "H"
          HeroineTresureTable.new(translate("LogHorizon.TRS.HTRS.name"), translate("LogHorizon.TRS.HTRS.items"))
        when "G"
          TresureTable.new(translate("LogHorizon.TRS.GTRS.name"), translate("LogHorizon.TRS.GTRS.items"))
        end
      end

      # 財宝表
      class TresureTable
        # @param name [String]
        # @param items [Hash{Integer => String}]
        def initialize(name, items)
          @name = name
          @items = items

          @dice_list = nil
        end

        # プライズ取得用にダイスの値を固定する
        # @param dice [Integer]
        # @return [void]
        def fix_dice_value(dice)
          @dice_list = [dice]
        end

        # @param cr [Integer]
        # @param modifier [Integer]
        # @param randomizer [Randomizer]
        # @return [String, nil]
        def roll(cr, modifier, randomizer)
          return nil if cr == 0 && modifier == 0

          index =
            if cr == 0 && modifier != 0
              modifier # modifierの値のみ設定されている場合には、その値の項目をダイスロールせずに参照する
            else
              @dice_list ||= randomizer.roll_barabara(2, 6)
              @dice_list.sum() + 5 * cr + modifier
            end
          chosen = pick_item(index)

          dice_str = "[#{@dice_list&.join(',')}]" if @dice_list

          "#{@name}(#{index}#{dice_str})：#{chosen}"
        end

        private

        # @param index [Integer]
        # @return [String]
        def pick_item(index)
          if index <= 6
            "6以下の出目は未定義です"
          elsif index <= 62
            @items[index]
          elsif index <= 72
            "#{@items[index - 10]}&80G"
          elsif index <= 82
            "#{@items[index - 20]}&160G"
          elsif index <= 87
            "#{@items[index - 30]}&260G"
          else
            "87以降の出目は未定義です"
          end
        end
      end

      # ヒロイン財宝表
      class HeroineTresureTable < TresureTable
        # @param index [Integer]
        # @return [String]
        def pick_item(index)
          if index <= 6
            "6以下の出目は未定義です"
          elsif index <= 53
            @items[index]
          else
            "53以降の出目は未定義です"
          end
        end
      end

      # 拡張ルール財宝表
      class ExpansionTresureTable < TresureTable
        # @param index [Integer]
        # @return [String]
        def pick_item(index)
          if index <= 6
            "6以下の出目は未定義です"
          elsif index <= 162
            @items[index]
          elsif index <= 172
            "#{@items[index - 10]}&200G"
          elsif index <= 182
            "#{@items[index - 20]}&400G"
          elsif index <= 187
            "#{@items[index - 30]}&600G"
          else
            "187以降の出目は未定義です"
          end
        end
      end

      CASH_TRESURE_RESULT_TABLE = {
        7 => '35G',
        8 => '40G',
        9 => '40G',
        10 => '40G',
        11 => '45G',
        12 => '45G',
        13 => '45G',
        14 => '50G',
        15 => '50G',
        16 => '50G',
        17 => '55G',
        18 => '55G',
        19 => '60G',
        20 => '60G',
        21 => '65G',
        22 => '70G',
        23 => '70G',
        24 => '75G',
        25 => '75G',
        26 => '80G',
        27 => '85G',
        28 => '85G',
        29 => '90G',
        30 => '95G',
        31 => '100G',
        32 => '100G',
        33 => '105G',
        34 => '110G',
        35 => '115G',
        36 => '120G',
        37 => '125G',
        38 => '130G',
        39 => '135G',
        40 => '140G',
        41 => '145G',
        42 => '150G',
        43 => '155G',
        44 => '160G',
        45 => '165G',
        46 => '170G',
        47 => '175G',
        48 => '180G',
        49 => '185G',
        50 => '195G',
        51 => '200G',
        52 => '205G',
        53 => '210G',
        54 => '220G',
        55 => '225G',
        56 => '230G',
        57 => '240G',
        58 => '245G',
        59 => '255G',
        60 => '260G',
        61 => '265G',
        62 => '275G',
        63 => '280G',
        64 => '290G',
        65 => '300G',
        66 => '300G',
        67 => '310G',
        68 => '320G',
        69 => '330G',
        70 => '340G',
        71 => '340G',
        72 => '350G',
        73 => '360G',
        74 => '370G',
        75 => '380G',
        76 => '390G',
        77 => '400G',
        78 => '410G',
        79 => '420G',
        80 => '430G',
        81 => '440G',
        82 => '450G',
        83 => '460G',
        84 => '460G',
        85 => '480G',
        86 => '490G',
        87 => '500G',
        88 => '510G',
        89 => '520G',
        90 => '530G',
        91 => '540G',
        92 => '550G',
        93 => '560G',
        94 => '570G',
        95 => '580G',
        96 => '590G',
        97 => '610G',
        98 => '620G',
        99 => '630G',
        100 => '640G',
        101 => '650G',
        102 => '660G',
        103 => '680G',
        104 => '690G',
        105 => '700G',
        106 => '710G',
        107 => '730G',
        108 => '740G',
        109 => '750G',
        110 => '760G',
        111 => '780G',
        112 => '790G',
        113 => '800G',
        114 => '820G',
        115 => '830G',
        116 => '840G',
        117 => '860G',
        118 => '870G',
        119 => '890G',
        120 => '900G',
        121 => '910G',
        122 => '930G',
        123 => '940G',
        124 => '960G',
        125 => '970G',
        126 => '990G',
        127 => '1000G',
        128 => '1020G',
        129 => '1030G',
        130 => '1050G',
        131 => '1060G',
        132 => '1080G',
        133 => '1090G',
        134 => '1110G',
        135 => '1130G',
        136 => '1140G',
        137 => '1160G',
        138 => '1170G',
        139 => '1190G',
        140 => '1210G',
        141 => '1220G',
        142 => '1240G',
        143 => '1260G',
        144 => '1270G',
        145 => '1290G',
        146 => '1310G',
        147 => '1330G',
        148 => '1340G',
        149 => '1360G',
        150 => '1380G',
        151 => '1400G',
        152 => '1410G',
        153 => '1430G',
        154 => '1450G',
        155 => '1470G',
        156 => '1490G',
        157 => '1500G',
        158 => '1520G',
        159 => '1540G',
        160 => '1560G',
        161 => '1580G',
        162 => '1600G',
      }.freeze

      # ロデ研の新発明ランダム決定表
      def getInventionAttributeTextDiceCommandResult(command)
        return nil unless command =~ /IAT([ABMDLT]*)/

        tableName = translate("LogHorizon.IAT.name")

        table_indicate_string = Regexp.last_match(1) && Regexp.last_match(1) != '' ? Regexp.last_match(1) : 'MDLT'
        is_single = (table_indicate_string.length == 1)

        result = []
        number = []

        table_indicate_string.split(//).each do |char|
          dice_result = @randomizer.roll_once(6)
          number << dice_result.to_s
          table =   case char
                    when 'A', 'M'
                      translate("LogHorizon.IAT.A")
                    when 'B', 'D'
                      translate("LogHorizon.IAT.B")
                    when 'L'
                      translate("LogHorizon.IAT.L")
                    when 'T'
                      translate("LogHorizon.IAT.T")
                    end
          chosen = table[:items][dice_result - 1]
          if is_single
            chosen = "#{table[:name]}：#{chosen}"
          end

          result.push(chosen)
        end

        return "#{tableName}([#{number.join(',')}])：#{result.join(' ')}"
      end

      # アキバの街で遭遇するトラブルランダム決定表
      def getTroubleInAkibaStreetDiceCommandResult(command)
        return nil unless command == "TIAS"

        tableName = translate("LogHorizon.TIAS.name")

        number = []
        result = []

        translate("LogHorizon.TIAS.tables").each do |table|
          dice_result = @randomizer.roll_once(6)
          number << dice_result.to_s
          result << table[dice_result - 1]
        end

        return "#{tableName}([#{number.join(',')}])：#{result.join(' ')}"
      end

      # 廃棄児ランダム決定表
      def getAbandonedChildDiceCommandResult(command)
        return nil unless command == "ABDC"

        tableName = translate("LogHorizon.ABDC.name")

        number = []
        result = []

        translate("LogHorizon.ABDC.tables").each do |table|
          dice_result = @randomizer.roll_once(6)
          number << dice_result.to_s
          result << table[dice_result - 1]
        end

        return "#{tableName}([#{number.join(',')}])：#{result.join('　')}"
      end

      # 楽器種別表
      def getMusicalInstrumentTypeDiceCommandResult(command)
        return nil unless command =~ /MII(\d?)/

        is_roll = !(Regexp.last_match(1) && Regexp.last_match(1) != '')
        type = is_roll ? @randomizer.roll_once(6) : Regexp.last_match(1).to_i

        return nil if type < 1 || 6 < type

        tableName = translate("LogHorizon.MII.name")
        type_name = translate("LogHorizon.MII.type_list")[type - 1]

        dice = @randomizer.roll_once(6)
        result = translate("LogHorizon.MII.items")[type - 1][dice - 1]

        return tableName.to_s + (is_roll ? "(#{type})" : '') + "：#{type_name}(#{dice})：#{result}"
      end

      # イースタル探索表
      def roll_eastal_exploration_table(command)
        m = /ESTL(\d+)?([\+\-\d]+)?(?:\$(\d+))?/.match(command)
        return nil unless m
        return nil if m[1].nil? && m[2].nil? && m[3].nil?

        character_rank = m[1].to_i
        modifier = ArithmeticEvaluator.eval(m[2])
        fixed_dice_value = m[3]&.to_i

        dice_list =
          if fixed_dice_value
            [fixed_dice_value]
          elsif character_rank == 0
            []
          else
            @randomizer.roll_barabara(2, 6)
          end

        dice_str = "[#{dice_list.join(',')}]" unless dice_list.empty?
        total = (dice_list.sum() + character_rank * 5 + modifier).clamp(7, 162)

        table_name = translate("LogHorizon.ESTL.name")
        table = translate("LogHorizon.ESTL.items")
        chosen = table[total].chomp

        return "#{table_name}(#{total}#{dice_str})\n#{chosen}"
      end

      class << self
        private

        def translate_tables(locale)
          {
            "PTAG" => DiceTable::D66Table.from_i18n("LogHorizon.table.PTAG", locale),
            "KOYU" => DiceTable::D66Table.from_i18n("LogHorizon.table.KOYU", locale),
            "MGR1" => DiceTable::D66Table.from_i18n("LogHorizon.table.MGR1", locale),
            "MGR2" => DiceTable::D66Table.from_i18n("LogHorizon.table.MGR2", locale),
            "MGR3" => DiceTable::D66Table.from_i18n("LogHorizon.table.MGR3", locale),
            "HLOC" => DiceTable::D66Table.from_i18n("LogHorizon.table.HLOC", locale),
            "PCNM" => DiceTable::D66Table.from_i18n("LogHorizon.table.PCNM", locale),
          }
        end
      end

      TABLES = translate_tables(:ja_jp)

      register_prefix(TABLES.keys)
    end
  end
end
