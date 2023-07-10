# Keccak256

Keccak256 - это криптографический алгоритм хэширования. Он является членом семейства хэш-функций SHA-3 и был выбран в качестве стандарта хэш-функций [NIST](https://ru.wikipedia.org/wiki/%D0%9D%D0%B0%D1%86%D0%B8%D0%BE%D0%BD%D0%B0%D0%BB%D1%8C%D0%BD%D1%8B%D0%B9_%D0%B8%D0%BD%D1%81%D1%82%D0%B8%D1%82%D1%83%D1%82_%D1%81%D1%82%D0%B0%D0%BD%D0%B4%D0%B0%D1%80%D1%82%D0%BE%D0%B2_%D0%B8_%D1%82%D0%B5%D1%85%D0%BD%D0%BE%D0%BB%D0%BE%D0%B3%D0%B8%D0%B9) в 2012 году. Очень подробно о том, как работает алгоритм, можно почитать [в стандарте](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf) и в [документации](https://keccak.team/files/Keccak-reference-3.0.pdf) от команды keccak, но там очень много криптографии, для понимания его работы достаточно знать только несколько основных вещей о хэш-фукнциях и о самом алгоритме.

## Что такое хэш-функция?

Хэш-функция - это функция, которая принимает произвольный набор данных в качестве входных данных (сообщение) и выдает фиксированную длину хэш-значения в качестве выходных данных (дайджест). Длина сообщения может варьироваться, но длина дайджеста фиксирована.

Хэш-функция не может быть обратимой, то есть невозможно вычислить входные данные по хэш-значению. Это означает, что хэш-функция не может быть использована для шифрования данных, но она может быть использована для создания цифровых подписей, которые могут быть проверены, чтобы убедиться, что данные не были изменены.

Хеш-функции являются компонентами для многих важных приложений информационной безопасности, включая:
1. генерацию и проверку цифровых подписей;
2. деривацию ключей (например используется для создание HD-кошельков, когда из мастер-ключа генерируются дочерние ключи (подробнее [тут](https://wolovim.medium.com/ethereum-201-hd-wallets-11d0c93c87f7)), что позволяет зная только мнемоническую фразу восстановить все аккаунты кошелька);
3. генерацию псевдослучайных битов (это процесс генерации последовательности битов, которые кажутся случайными, но на самом деле генерируются детерминированным алгоритмом, при этом без ключа нельзя угадать эту последовательность).

## Почему keccak256?

Длина дайджеста (выходных данных) криптографической функции может быть разной, например 160, 224, 256, 384 и 512 бит. Чем больше длина дайджеста, тем больше информации он может содержать, но тем дольше будет процесс его вычисления. Поэтому, как правило, используются дайджесты длиной 256 бит, так как они достаточно длинные, чтобы содержать достаточно информации, но при этом вычисляются достаточно быстро.

Keccak256 считается высокозащищенным алгоритмом хэширования, который устойчив к различным типам атак, таким как атаки на предварительный образ, атаки на коллизии и атаки на увеличение длины. При этом он является одним из самых эффективных алгоритмов хэширования и его поддерживает большое количество библиотек. По этим причинам он был выбран для использования в таких блокчейнах как Ethereum и Bitcoin для выполнения различных задач.

Функции семейства keccak основаны на функции губки. В контексте криптографии конструкция губки — это режим работы, основанный на перестановке (или преобразовании) фиксированной длины, а также правиле заполнения, которое строит функцию, отображающую ввод переменной длины в вывод переменной длины. Подробнее о функции губки [тут](https://keccak.team/sponge_duplex.html).

## Keccak256 в Solidity

`keccak256` — это также функция, встроенная в Solidity. Она принимает любое количество входных данных и преобразует их в уникальный 32-байтовый хэш (32 байта это как раз 256 бит).

Можно попробовать выполнить этот код в [Remix](https://remix.ethereum.org/#lang=en&optimize=false&runs=200&evmVersion=null&version=soljson-v0.8.18+commit.87f61d96.js). Нужно ввести текст, число и адрес Ethereum в функцию чтобы получить на вывод хэш `bytes32`. Затем изменить один из параметров и повторно сгенерировать вывод хэша - можно заметить, что хэш изменился. Если ввести первоначальные параметры то можно снова получить исходны хэш.

```js
    pragma solidity 0.8.17;

    contract Hash {
        function hash(string memory _text, uint256 _number, address _address) public pure returns (bytes32) {
            return keccak256(abi.encodePacked(_text, _number, _address));
        }
    }
```

В смарт-контрактах функция `keccak256` используется для различных целей, например работа с подписями, создание хэш-таблиц (маппингов), вычисление селектора функций, работа с деревом Меркла и т.д.

Также фукнция `keccak256` может быть использована не только для служебных целей, но и для определенной логики на смарт-контракте, например в схеме commit-reveal, когда пользователь сначала отправляет транзакцию с хэшированными данными, а затем отправляет реальные данные, которые будут проверены на соответствие этому хэшу.

## Links

1. [SHA-3 Standard](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf)
2. [Keccak](https://keccak.team/keccak_specs_summary.html)
3. [Ethereum 201: HD Wallets](https://wolovim.medium.com/ethereum-201-hd-wallets-11d0c93c87f7)
4. [Hashing Functions In Solidity Using Keccak256](https://medium.com/0xcode/hashing-functions-in-solidity-using-keccak256-70779ea55bb0)
5. [Hashing with Keccak256](https://solidity-by-example.org/hashing/)
6. [Keccak-256 online tool](https://emn178.github.io/online-tools/keccak_256.html)